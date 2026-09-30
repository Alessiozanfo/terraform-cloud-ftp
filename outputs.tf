output "storage_bucket_name" {
  description = "Name of the Google Cloud Storage bucket used for SFTP files"
  value       = google_storage_bucket.ftp_storage.name
}

output "cloud_ftp_server_id" {
  description = "Server ID of the native Google Cloud FTP server"
  value       = google_storage_ftp_server.managed_sftp.server_id
}

output "cloud_ftp_service_agent" {
  description = "Email of the unique Service Agent generated automatically for this Cloud FTP server"
  value       = google_storage_ftp_server.managed_sftp.service_agent
}

output "configured_ftp_users" {
  description = "List of configured SFTP users on Cloud FTP"
  value       = keys(var.ftp_users)
}

output "sftp_connection_syntax" {
  description = "Command syntax to connect via an SFTP client using SSH key authentication"
  value       = "sftp -i <path_to_private_ssh_key> <user_id>@<SERVER_HOST_OR_IP>"
}
