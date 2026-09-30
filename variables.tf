variable "project_id" {
  description = "ID del progetto Google Cloud"
  type        = string
}

variable "region" {
  description = "Regione GCP dove distribuire le risorse (es. europe-west1, europe-west8)"
  type        = string
  default     = "europe-west1"
}

variable "bucket_name" {
  description = "Nome univoco del bucket Cloud Storage. Se null, verrà generato usando il project_id."
  type        = string
  default     = null
}

variable "cloud_ftp_server_id" {
  description = "ID del server Cloud FTP gestito (max 30 caratteri alfanumerici e trattini)"
  type        = string
  default     = "partner-sftp-srv"
}

variable "allowed_cidr_blocks" {
  description = "Elenco dei blocchi CIDR IP autorizzati a connettersi al server Cloud FTP esterno"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "labels" {
  description = "Etichette opzionali da applicare alle risorse Cloud FTP"
  type        = map(string)
  default     = {}
}

variable "ftp_users" {
  description = "Mappa degli utenti SFTP nativi con relative chiavi pubbliche SSH e configurazione directory"
  type = map(object({
    ssh_public_keys = list(string)
    display_name    = optional(string)
    bucket_prefix   = optional(string)
    directory       = optional(string)
  }))
  default = {}
}
