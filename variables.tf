variable "aws_region" {
  description = "Regione AWS dove distribuire le risorse"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Ambiente di deploy (es. dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "server_name" {
  description = "Nome identificativo del Cloud FTP Server"
  type        = string
  default     = "cloud-ftp-server"
}

variable "bucket_name" {
  description = "Nome univoco per il bucket S3 di storage. Se vuoto o null, verrà generato automaticamente con prefisso."
  type        = string
  default     = null
}

variable "protocols" {
  description = "Protocolli abilitati per il server AWS Transfer (SFTP, FTPS, FTP). Per FTP puro o FTPS è consigliato un endpoint VPC."
  type        = list(string)
  default     = ["SFTP"]
}

variable "endpoint_type" {
  description = "Tipo di endpoint: PUBLIC oppure VPC"
  type        = string
  default     = "PUBLIC"
}

variable "ftp_users" {
  description = "Mappa degli utenti FTP/SFTP da creare con le relative chiavi pubbliche SSH"
  type = map(object({
    ssh_public_key = string
  }))
  default = {}
}
