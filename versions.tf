terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.3.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.3.0"
    }
  }

  # Configurazione opzionale per il backend remoto su GCS
  # backend "gcs" {
  #   bucket = "mio-terraform-state-bucket"
  #   prefix = "cloud-ftp/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
