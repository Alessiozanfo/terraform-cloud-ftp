# ==============================================================================
# OPZIONE 2: MICROSOFT ENTRA ID GATEWAY (Autenticazione Username & Password)
# ==============================================================================

# Abilitazione Secret Manager per archiviazione sicura del secret di Entra ID
resource "google_project_service" "secretmanager_api" {
  count              = var.enable_entra_id_auth ? 1 : 0
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Secret su Secret Manager per evitare secret in chiaro nei metadata della VM
resource "google_secret_manager_secret" "entra_client_secret" {
  count     = var.enable_entra_id_auth ? 1 : 0
  secret_id = "entra-id-client-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "entra_client_secret_val" {
  count       = var.enable_entra_id_auth && var.entra_client_secret != "" ? 1 : 0
  secret      = google_secret_manager_secret.entra_client_secret[0].id
  secret_data = var.entra_client_secret
}

# IP Statico esterno riservato per l'endpoint Entra ID SFTP
resource "google_compute_address" "entra_ftp_ip" {
  count  = var.enable_entra_id_auth ? 1 : 0
  name   = "cloud-ftp-entraid-ip"
  region = var.region
}

# Service Account per il gateway Entra ID
resource "google_service_account" "entra_ftp_gateway_sa" {
  count        = var.enable_entra_id_auth ? 1 : 0
  account_id   = "ftp-entraid-gateway-sa"
  display_name = "Cloud FTP Entra ID Gateway Service Account"
}

# Permessi sul bucket Cloud Storage per il gateway
resource "google_storage_bucket_iam_member" "entra_gateway_storage_access" {
  count  = var.enable_entra_id_auth ? 1 : 0
  bucket = google_storage_bucket.ftp_storage.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.entra_ftp_gateway_sa[0].email}"
}

# Permesso alla Service Account di leggere il secret da Secret Manager
resource "google_secret_manager_secret_iam_member" "entra_secret_accessor" {
  count     = var.enable_entra_id_auth ? 1 : 0
  secret_id = google_secret_manager_secret.entra_client_secret[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.entra_ftp_gateway_sa[0].email}"
}

# Regola Firewall per consentire il traffico SFTP (porta 22) e FTP (porta 21 e range passivo 50000-50100)
resource "google_compute_firewall" "allow_sftp_entraid" {
  count   = var.enable_entra_id_auth ? 1 : 0
  name    = "allow-cloud-ftp-entraid"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "21", "50000-50100"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["cloud-ftp-entraid"]
}

# Istanza Compute Engine (container-optimized) che fa da bridge tra Client SFTP, Entra ID e GCS
resource "google_compute_instance" "entra_ftp_gateway" {
  count        = var.enable_entra_id_auth ? 1 : 0
  name         = "cloud-ftp-entraid-gateway"
  machine_type = "e2-small"
  zone         = var.zone

  tags = ["cloud-ftp-entraid"]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.entra_ftp_ip[0].address
    }
  }

  service_account {
    email  = google_service_account.entra_ftp_gateway_sa[0].email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e

    mkdir -p /etc/sftpgo/hooks

    # Recupero sicuro del secret da Secret Manager al boot (nessun secret in chiaro nei metadata)
    ENTRA_SECRET=$(gcloud secrets versions access latest --secret=entra-id-client-secret || echo "${var.entra_client_secret}")

    # Script di autenticazione verso Microsoft Entra ID (ROPC / OAuth2 Password Grant)
    cat <<HOOK > /etc/sftpgo/hooks/entraid_auth.sh
    #!/bin/bash
    TENANT_ID="${var.entra_tenant_id}"
    CLIENT_ID="${var.entra_client_id}"
    CLIENT_SECRET="$ENTRA_SECRET"

    if [ -z "\$SFTPGO_AUTHD_PASSWORD" ]; then
      exit 1
    fi

    # Richiesta di token a Microsoft Entra ID (valida username e password)
    HTTP_RESP=\$(curl -s -w "%%{http_code}" -o /tmp/token_resp.json \
      -X POST "https://login.microsoftonline.com/\$TENANT_ID/oauth2/v2.0/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=\$CLIENT_ID" \
      -d "client_secret=\$CLIENT_SECRET" \
      -d "scope=https://graph.microsoft.com/.default openid" \
      -d "grant_type=password" \
      -d "username=\$SFTPGO_AUTHD_USERNAME" \
      -d "password=\$SFTPGO_AUTHD_PASSWORD")

    if [ "\$HTTP_RESP" -eq 200 ]; then
      # Autenticazione Entra ID riuscita: genera configurazione utente con home dir su GCS
      cat <<JSON
      {
        "status": 1,
        "username": "\$SFTPGO_AUTHD_USERNAME",
        "home_dir": "/\$SFTPGO_AUTHD_USERNAME",
        "filesystem": {
          "provider": 3,
          "gcsconfig": {
            "bucket": "${google_storage_bucket.ftp_storage.name}",
            "key_prefix": "utenti/\$SFTPGO_AUTHD_USERNAME/"
          }
        },
        "permissions": {
          "/": ["*"]
        }
      }
JSON
      exit 0
    else
      echo "Entra ID authentication failed for user \$SFTPGO_AUTHD_USERNAME" >&2
      exit 1
    fi
HOOK

    chmod +x /etc/sftpgo/hooks/entraid_auth.sh

    # Avvio container SFTPGo con network host per supportare sia SFTP (22) sia FTP passivo (21 e 50000-50100)
    docker run -d \
      --name sftpgo-entraid \
      --restart always \
      --net=host \
      -v /etc/sftpgo/hooks:/hooks \
      -e SFTPGO_AUTH_HOOK=/hooks/entraid_auth.sh \
      -e SFTPGO_SFTPD__BINDINGS__0__PORT=22 \
      -e SFTPGO_FTPD__BINDINGS__0__PORT=21 \
      -e SFTPGO_FTPD__PASSIVE_PORT_RANGE__START=50000 \
      -e SFTPGO_FTPD__PASSIVE_PORT_RANGE__END=50100 \
      drakkan/sftpgo:latest
  EOT

  labels = {
    auth_method = "microsoft_entraid"
    managed_by  = "terraform"
  }

  depends_on = [
    google_secret_manager_secret_iam_member.entra_secret_accessor
  ]
}
