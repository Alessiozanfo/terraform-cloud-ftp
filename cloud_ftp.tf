# ==============================================================================
# NATIVE MANAGED GOOGLE CLOUD FTP (Serverless SFTP over Google Cloud Storage)
# ==============================================================================

# Enable native Google Cloud FTP API
resource "google_project_service" "ftp_api" {
  service            = "ftp.googleapis.com"
  disable_on_destroy = false
}

# IAM API is required to create the per-user service accounts and their bindings
# (usually already enabled, but not guaranteed in freshly created projects).
resource "google_project_service" "iam_api" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# Fully managed native Cloud FTP server instance (no VMs or containers to manage)
resource "google_storage_ftp_server" "managed_sftp" {
  server_id    = var.cloud_ftp_server_id
  location     = var.region
  display_name = "Managed SFTP server (${var.cloud_ftp_server_id})"
  access_type  = "EXTERNAL"

  external_config {
    # The only network-level control of an EXTERNAL server: keep it tight.
    allowed_cidr_blocks = var.allowed_cidr_blocks
  }

  labels = merge(var.labels, {
    managed_by = "terraform"
    service    = "cloud-ftp"
  })

  depends_on = [google_project_service.ftp_api]
}

# Dedicated Google Cloud Service Account for each SFTP user.
# NOTE: the SFTP user authenticates with its SSH key and accesses GCS *as this
# service account*; it is not tied to any human identity (see README).
resource "google_service_account" "ftp_user_sa" {
  for_each = var.ftp_users

  # Service account IDs must be RFC1035 names (lowercase letters, digits, hyphens;
  # 6-30 chars): the ftp_users key format is validated accordingly in variables.tf.
  account_id   = "ftp-usr-${each.key}"
  display_name = coalesce(each.value.display_name, "SFTP User SA for ${each.key}")

  depends_on = [google_project_service.iam_api]
}

# Granular IAM permission allowing the user's Service Account to access the bucket.
# roles/storage.objectUser covers every permission the Cloud FTP data plane needs
# for READ_WRITE mappings (objects get/list/create/delete/update, folders for HNS
# buckets) without granting object ACL/IAM administration.
resource "google_storage_bucket_iam_member" "user_bucket_access" {
  for_each = var.ftp_users

  bucket = google_storage_bucket.ftp_storage.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.ftp_user_sa[each.key].email}"
}

# Grant TokenCreator role to the server-unique Cloud FTP Service Agent so that it
# can impersonate the user SA when the user reads/writes the bucket.
resource "google_service_account_iam_member" "ftp_agent_token_creator" {
  for_each = var.ftp_users

  service_account_id = google_service_account.ftp_user_sa[each.key].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_storage_ftp_server.managed_sftp.service_agent}"
}

# Provision the Cloud FTP user with directory mapping and authorized SSH public keys.
# The API validates at creation time that the *caller* can act as the customer
# service account (roles/iam.serviceAccountUser) and can read the bucket metadata
# (storage.buckets.get): see the prerequisites in the README.
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

  labels = merge(var.labels, {
    managed_by = "terraform"
    service    = "cloud-ftp"
  })

  depends_on = [
    google_storage_bucket_iam_member.user_bucket_access,
    google_service_account_iam_member.ftp_agent_token_creator,
  ]
}
