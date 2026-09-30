# Abilitazione API Cloud Storage
resource "google_project_service" "storage_api" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Bucket centrale Google Cloud Storage condiviso tra i due metodi di autenticazione
resource "google_storage_bucket" "ftp_storage" {
  name          = var.bucket_name != null ? var.bucket_name : "${var.project_id}-cloud-ftp-storage"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = {
    service   = "cloud-ftp"
    managed_by = "terraform"
  }

  depends_on = [google_project_service.storage_api]
}
