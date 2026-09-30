# ==============================================================================
# OPZIONE 2: MICROSOFT ENTRA ID GATEWAY (Autenticazione Username & Password)
# ==============================================================================

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

# Regola Firewall per consentire il traffico SFTP (porta 22) e FTP (porta 21 e passive)
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

    # Script di autenticazione verso Microsoft Entra ID (ROPC / OAuth2 Password Grant)
    cat <<'HOOK' > /etc/sftpgo/hooks/entraid_auth.sh
    #!/bin/bash
    # SFTPGo passa USERNAME e PASSWORD tramite variabili d'ambiente
    TENANT_ID="${var.entra_tenant_id}"
    CLIENT_ID="${var.entra_client_id}"
    CLIENT_SECRET="${var.entra_client_secret}"

    if [ -z "$SFTPGO_AUTHD_PASSWORD" ]; then
      exit 1
    fi

    # Richiesta di token a Microsoft Entra ID
    HTTP_RESP=$(curl -s -w "%%{http_code}" -o /tmp/token_resp.json \
      -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$CLIENT_ID" \
      -d "client_secret=$CLIENT_SECRET" \
      -d "scope=https://graph.microsoft.com/.default openid" \
      -d "grant_type=password" \
      -d "username=$SFTPGO_AUTHD_USERNAME" \
      -d "password=$SFTPGO_AUTHD_PASSWORD")

    if [ "$HTTP_RESP" -eq 200 ]; then
      # Autenticazione Entra ID riuscita: genera configurazione utente con home dir su GCS
      cat <<JSON
      {
        "status": 1,
        "username": "$SFTPGO_AUTHD_USERNAME",
        "home_dir": "/$SFTPGO_AUTHD_USERNAME",
        "filesystem": {
          "provider": 3,
          "gcsconfig": {
            "bucket": "${google_storage_bucket.ftp_storage.name}",
            "key_prefix": "utenti/$SFTPGO_AUTHD_USERNAME/"
          }
        },
        "permissions": {
          "/": ["*"]
        }
      }
JSON
      exit 0
    else
      echo "Entra ID authentication failed for user $SFTPGO_AUTHD_USERNAME" >&2
      exit 1
    fi
HOOK

    chmod +x /etc/sftpgo/hooks/entraid_auth.sh

    # Avvio del container SFTPGo con GCS nativo e Auth Hook Entra ID
    docker run -d \
      --name sftpgo-entraid \
      --restart always \
      -p 22:2022 \
      -p 21:2121 \
      -v /etc/sftpgo/hooks:/hooks \
      -e SFTPGO_AUTH_HOOK=/hooks/entraid_auth.sh \
      -e SFTPGO_SFTPD__BINDINGS__0__PORT=2022 \
      -e SFTPGO_FTPD__BINDINGS__0__PORT=2121 \
      drakkan/sftpgo:latest
  EOT

  labels = {
    auth_method = "microsoft_entraid"
    managed_by  = "terraform"
  }
}
