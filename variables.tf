variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "The Google Cloud region to deploy resources into (e.g. europe-west1, us-central1)"
  type        = string
  default     = "europe-west1"
}

variable "bucket_name" {
  description = "Unique name for the Cloud Storage bucket. If null, defaults to '<project_id>-cloud-ftp-storage'."
  type        = string
  default     = null
}

variable "cloud_ftp_server_id" {
  description = "ID of the managed Cloud FTP server (up to 30 alphanumeric characters and hyphens)"
  type        = string
  default     = "partner-sftp-srv"
}

variable "allowed_cidr_blocks" {
  description = "List of allowed CIDR IP blocks authorized to connect to the external Cloud FTP server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "labels" {
  description = "Optional key-value labels to apply to Cloud FTP resources"
  type        = map(string)
  default     = {}
}

variable "ftp_users" {
  description = "Map of native SFTP users with their SSH public keys and directory configuration"
  type = map(object({
    ssh_public_keys = list(string)
    display_name    = optional(string)
    bucket_prefix   = optional(string)
    directory       = optional(string)
  }))
  default = {}
}
