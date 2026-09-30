variable "project_id" {
  description = "ID del progetto Google Cloud"
  type        = string
}

variable "region" {
  description = "Regione GCP dove distribuire le risorse (es. europe-west1, europe-west8)"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zona GCP per eventuali risorse zonali"
  type        = string
  default     = "europe-west1-b"
}

variable "bucket_name" {
  description = "Nome univoco del bucket Cloud Storage. Se null, verrà generato usando il project_id."
  type        = string
  default     = null
}

# ==============================================================================
# OPZIONE 1: GCP IAM NATIVE (Cloud FTP Gestito da Google)
# ==============================================================================
variable "enable_gcp_iam_auth" {
  description = "Abilita il server Cloud FTP nativo di Google Cloud con autenticazione IAM e chiavi SSH"
  type        = bool
  default     = true
}

variable "cloud_ftp_server_id" {
  description = "ID del server Cloud FTP gestito (max 30 caratteri alfanumerici e trattini)"
  type        = string
  default     = "managed-cloud-ftp"
}

variable "iam_ftp_users" {
  description = "Mappa degli utenti SFTP nativi IAM con relative chiavi pubbliche SSH"
  type = map(object({
    ssh_public_keys = list(string)
    display_name    = optional(string)
  }))
  default = {}
}

# ==============================================================================
# OPZIONE 2: MICROSOFT ENTRA ID (Username & Password delegata a Microsoft)
# ==============================================================================
variable "enable_entra_id_auth" {
  description = "Abilita il gateway di autenticazione SFTP/FTP con convalida Username e Password delegata a Microsoft Entra ID"
  type        = bool
  default     = true
}

variable "entra_tenant_id" {
  description = "Directory (tenant) ID di Microsoft Entra ID (Azure AD)"
  type        = string
  default     = ""
}

variable "entra_client_id" {
  description = "Application (client) ID della registrazione app su Entra ID"
  type        = string
  default     = ""
}

variable "entra_client_secret" {
  description = "Client secret dell'applicazione su Entra ID"
  type        = string
  default     = ""
  sensitive   = true
}
