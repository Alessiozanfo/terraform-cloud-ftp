# ==============================================================================
# OPZIONE 1: GOOGLE CLOUD FTP NATIVO (IAM Service Accounts + SSH Keys)
# ==============================================================================

# Abilitazione API Cloud FTP nativa di Google
resource "google_project_service" "ftp_api" {
  count              = var.enable_gcp_iam_auth ? 1 : 0
  service            = "ftp.googleapis.com"
  disable_on_destroy = false
}

data "google_project" "current" {}

# Server Cloud FTP nativo gestito
resource "google_storage_ftp_server" "managed_sftp" {
  count     = var.enable_gcp_iam_auth ? 1 : 0
  server_id = var.cloud_ftp_server_id
  location  = var.region

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

# Permesso al Service Agent nativo di Cloud FTP di generare token per la Service Account
resource "google_service_account_iam_member" "ftp_agent_token_creator" {
  for_each = var.enable_gcp_iam_auth ? var.iam_ftp_users : {}

  service_account_id = google_service_account.iam_ftp_user_sa[each.key].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-ftp.iam.gserviceaccount.com"

  depends_on = [google_project_service.ftp_api]
}

# Provisioning dell'utente Cloud FTP con associazione a Service Account e chiave SSH pubblica
resource "google_storage_ftp_user" "managed_user" {
  for_each = var.enable_gcp_iam_auth ? var.iam_ftp_users : {}

  server_id       = google_storage_ftp_server.managed_sftp[0].server_id
  location        = var.region
  username        = each.key
  service_account = google_service_account.iam_ftp_user_sa[each.key].email
  ssh_public_keys = each.value.ssh_public_keys

  depends_on = [
    google_service_account_iam_member.ftp_agent_token_creator
  ]
}
