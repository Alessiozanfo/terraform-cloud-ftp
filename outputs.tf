output "server_id" {
  description = "ID del server AWS Transfer"
  value       = aws_transfer_server.ftp_server.id
}

output "server_endpoint" {
  description = "Endpoint DNS del server Cloud FTP / SFTP"
  value       = aws_transfer_server.ftp_server.endpoint
}

output "s3_bucket_name" {
  description = "Nome del bucket S3 utilizzato per lo storage dei file"
  value       = aws_s3_bucket.ftp_storage.id
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.ftp_storage.arn
}

output "configured_users" {
  description = "Lista degli utenti configurati"
  value       = keys(var.ftp_users)
}

output "sftp_connection_example" {
  description = "Esempio di comando per connettersi via SFTP (per il primo utente configurato se presente)"
  value = length(keys(var.ftp_users)) > 0 ? "sftp -i <chiave_privata> ${element(keys(var.ftp_users), 0)}@${aws_transfer_server.ftp_server.endpoint}" : "Nessun utente definito in ftp_users"
}
