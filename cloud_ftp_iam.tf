# ==============================================================================
# OPZIONE 1: GOOGLE CLOUD FTP NATIVO (IAM Service Accounts + SSH Keys)
# ==============================================================================

# Abilitazione API Cloud FTP nativa di Google
resource "google_project_service" "ftp_api" {
  count              = var.enable_gcp_iam_auth ? 1 : 0
  service            = "ftp.googleapis.com"
  disable_on_destroy = false
}

# Server Cloud FTP nativo gestito
resource "google_storage_ftp_server" "managed_sftp" {
  count       = var.enable_gcp_iam_auth ? 1 : 0
  server_id   = var.cloud_ftp_server_id
  location    = var.region
  access_type = "EXTERNAL"

  external_config {
    allowed_cidr_blocks = ["0.0.0.0/0"]
  }

  labels = {
    auth_method = "gcp_iam"
    managed_by  = "terraform"
  }

  depends_on = [
    google_project_service.ftp_api,
    google_storage_bucket.ftp_storage
  ]
}

# Service Account GCP per ciascun utente IAM SFTP
resource "google_service_account" "iam_ftp_user_sa" {
  for_each = var.enable_gcp_iam_auth ? var.iam_ftp_users : {}

  account_id   = "ftp-usr-${each.key}"
  display_name = coalesce(each.value.display_name, "SFTP User SA for ${each.key}")
}

# Permesso alla Service Account dell'utente per operare sul bucket Cloud Storage
resource "google_storage_bucket_iam_member" "iam_user_bucket_access" {
  for_each = var.enable_gcp_iam_auth ? var.iam_ftp_users : {}

  bucket = google_storage_bucket.ftp_storage.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.iam_ftp_user_sa[each.key].email}"
}

# Permesso al Service Agent univoco di Cloud FTP di generare token per conto della Service Account
resource "google_service_account_iam_member" "ftp_agent_token_creator" {
  for_each = var.enable_gcp_iam_auth ? var.iam_ftp_users : {}

  service_account_id = google_service_account.iam_ftp_user_sa[each.key].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_storage_ftp_server.managed_sftp[0].service_agent}"

  depends_on = [
    google_storage_ftp_server.managed_sftp
  ]
}

# Provisioning dell'utente Cloud FTP con storage directory mapping e credenziali SSH pubbliche
resource "google_storage_ftp_user" "managed_user" {
  for_each = var.enable_gcp_iam_auth ? var.iam_ftp_users : {}

  server_id                = google_storage_ftp_server.managed_sftp[0].server_id
  location                 = var.region
  user_id                  = each.key
  customer_service_account = google_service_account.iam_ftp_user_sa[each.key].email

  storage_directory_mappings {
    bucket        = google_storage_bucket.ftp_storage.name
    bucket_prefix = "incoming/${each.key}"
    directory     = "/incoming"
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
