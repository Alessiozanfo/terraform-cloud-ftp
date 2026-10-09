terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # google_storage_ftp_server / google_storage_ftp_user are GA resources
    # (added in 8.2.0); `service_agent`, `external_config.ip_address` and the
    # per-user `username` attribute used by this configuration require >= 8.5.0.
    google = {
      source  = "hashicorp/google"
      version = ">= 8.5.0, < 9.0.0"
    }
  }

  # Optional configuration for remote GCS backend
  # backend "gcs" {
  #   bucket = "my-terraform-state-bucket"
  #   prefix = "cloud-ftp/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
