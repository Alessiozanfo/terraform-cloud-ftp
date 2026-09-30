output "storage_bucket_name" {
  description = "Nome del bucket Cloud Storage utilizzato per archiviare i file"
  value       = google_storage_bucket.ftp_storage.name
}

# Output per lo scenario 1: Cloud FTP Nativo IAM
output "native_cloud_ftp_server_id" {
  description = "Server ID del server Cloud FTP nativo di Google Cloud"
  value       = var.enable_gcp_iam_auth ? google_storage_ftp_server.managed_sftp[0].server_id : "Disabilitato"
}

output "native_cloud_ftp_users" {
  description = "Utenti configurati con identità IAM GCP e chiavi SSH"
  value       = var.enable_gcp_iam_auth ? keys(var.iam_ftp_users) : []
}

# Output per lo scenario 2: Entra ID Gateway
output "entraid_ftp_endpoint_ip" {
  description = "Indirizzo IP statico per la connessione SFTP/FTP con credenziali Microsoft Entra ID"
  value       = var.enable_entra_id_auth ? google_compute_address.entra_ftp_ip[0].address : "Disabilitato"
}

output "entraid_sftp_connection_example" {
  description = "Esempio di comando per connettersi via SFTP con credenziali Entra ID"
  value = var.enable_entra_id_auth ? "sftp utente.aziendale@dominio.it@${google_compute_address.entra_ftp_ip[0].address}" : "Disabilitato"
}
