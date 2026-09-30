# ==============================================================================
# NATIVE MANAGED GOOGLE CLOUD FTP (Serverless SFTP over Google Cloud Storage)
# ==============================================================================

# Enable native Google Cloud FTP API
resource "google_project_service" "ftp_api" {
  service            = "ftp.googleapis.com"
  disable_on_destroy = false
}

# Fully managed native Cloud FTP server instance (no VMs or containers to manage)
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

# Dedicated Google Cloud Service Account for each SFTP user (governed by Entra ID / Cloud Identity lifecycle)
resource "google_service_account" "ftp_user_sa" {
  for_each = var.ftp_users

  account_id   = "ftp-usr-${each.key}"
  display_name = coalesce(each.value.display_name, "SFTP User SA for ${each.key}")
}

# Granular IAM permission allowing the user's Service Account to access the Cloud Storage bucket
resource "google_storage_bucket_iam_member" "user_bucket_access" {
  for_each = var.ftp_users

  bucket = google_storage_bucket.ftp_storage.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.ftp_user_sa[each.key].email}"
}

# Grant TokenCreator role to the server-unique Cloud FTP Service Agent to impersonate the user SA
resource "google_service_account_iam_member" "ftp_agent_token_creator" {
  for_each = var.ftp_users

  service_account_id = google_service_account.ftp_user_sa[each.key].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_storage_ftp_server.managed_sftp.service_agent}"

  depends_on = [
    google_storage_ftp_server.managed_sftp
  ]
}

# Provision the Cloud FTP user with directory mapping and authorized SSH public keys
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
