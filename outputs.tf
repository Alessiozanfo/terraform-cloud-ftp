output "storage_bucket_name" {
  description = "Nome del bucket Cloud Storage utilizzato per archiviare i file"
  value       = google_storage_bucket.ftp_storage.name
}

output "cloud_ftp_server_id" {
  description = "Server ID del server Cloud FTP nativo di Google Cloud"
  value       = google_storage_ftp_server.managed_sftp.server_id
}

output "cloud_ftp_service_agent" {
  description = "Email del Service Agent generato automaticamente per questo server Cloud FTP"
  value       = google_storage_ftp_server.managed_sftp.service_agent
}

output "configured_ftp_users" {
  description = "Elenco degli utenti SFTP censiti su Cloud FTP"
  value       = keys(var.ftp_users)
}

output "sftp_connection_syntax" {
  description = "Sintassi per collegarsi via client SFTP con chiave SSH"
  value       = "sftp -i <percorso_chiave_privata_ssh> <user_id>@<HOST_O_IP_SERVER>"
}
