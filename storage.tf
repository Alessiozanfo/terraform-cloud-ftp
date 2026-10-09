# Enable Cloud Storage API
resource "google_project_service" "storage_api" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Central Google Cloud Storage bucket for SFTP files
resource "google_storage_bucket" "ftp_storage" {
  name          = var.bucket_name != null ? var.bucket_name : "${var.project_id}-cloud-ftp-storage"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Live objects older than 90 days move to Nearline.
  lifecycle_rule {
    condition {
      age        = 90
      with_state = "LIVE"
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Versioning keeps every overwritten/deleted file forever unless noncurrent
  # versions are pruned: keep the 3 most recent noncurrent versions, drop older ones.
  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    service    = "cloud-ftp"
    managed_by = "terraform"
  }

  depends_on = [google_project_service.storage_api]
}
