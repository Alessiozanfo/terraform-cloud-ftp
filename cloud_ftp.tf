# ==============================================================================
# GOOGLE CLOUD FTP NATIVO E GESTITO (Serverless SFTP su Google Cloud Storage)
# ==============================================================================

# Abilitazione API Cloud FTP nativa di Google Cloud
resource "google_project_service" "ftp_api" {
  service            = "ftp.googleapis.com"
  disable_on_destroy = false
}

# Istanza Cloud FTP nativa completamente gestita (senza VM o container da gestire)
resource "google_storage_ftp_server" "managed_sftp" {
  server_id   = var.cloud_ftp_server_id
  location    = var.region
  access_type = "EXTERNAL"

  external_config {
    allowed_cidr_blocks = var.allowed_cidr_blocks
  }

  labels = merge(var.labels, {
    managed_by = "terraform"
    service    = "cloud-ftp"
  })

  depends_on = [
    google_project_service.ftp_api,
    google_storage_bucket.ftp_storage
  ]
}

# Service Account GCP per ciascun utente SFTP (identità collegata al ciclo di vita Entra ID / Cloud Identity)
resource "google_service_account" "ftp_user_sa" {
  for_each = var.ftp_users

  account_id   = "ftp-usr-${each.key}"
  display_name = coalesce(each.value.display_name, "SFTP User SA for ${each.key}")
}

# Permesso granulare alla Service Account dell'utente per operare sul bucket Cloud Storage
resource "google_storage_bucket_iam_member" "user_bucket_access" {
  for_each = var.ftp_users

  bucket = google_storage_bucket.ftp_storage.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.ftp_user_sa[each.key].email}"
}

# Concessione di TokenCreator al Service Agent univoco di Cloud FTP per impersonare la Service Account
resource "google_service_account_iam_member" "ftp_agent_token_creator" {
  for_each = var.ftp_users

  service_account_id = google_service_account.ftp_user_sa[each.key].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_storage_ftp_server.managed_sftp.service_agent}"

  depends_on = [
    google_storage_ftp_server.managed_sftp
  ]
}

# Provisioning dell'utente Cloud FTP con storage directory mapping e credenziali a chiavi pubbliche SSH
resource "google_storage_ftp_user" "managed_user" {
  for_each = var.ftp_users

  server_id                = google_storage_ftp_server.managed_sftp.server_id
  location                 = var.region
  user_id                  = each.key
  customer_service_account = google_service_account.ftp_user_sa[each.key].email

  storage_directory_mappings {
    bucket        = google_storage_bucket.ftp_storage.name
    bucket_prefix = coalesce(each.value.bucket_prefix, "incoming/${each.key}")
    directory     = coalesce(each.value.directory, "/incoming")
    permission    = "READ_WRITE"
  }

  dynamic "user_credentials" {
    for_each = each.value.ssh_public_keys
    content {
      credential_name     = "key-${user_credentials.key}"
      credential_type     = "PUBLIC_KEY"
      ssh_public_key_body = user_credentials.value
    }
  }

  depends_on = [
    google_service_account_iam_member.ftp_agent_token_creator
  ]
}
