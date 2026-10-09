output "storage_bucket_name" {
  description = "Name of the Google Cloud Storage bucket used for SFTP files"
  value       = google_storage_bucket.ftp_storage.name
}

output "cloud_ftp_server_id" {
  description = "Server ID of the native Google Cloud FTP server"
  value       = google_storage_ftp_server.managed_sftp.server_id
}

output "cloud_ftp_server_state" {
  description = "Lifecycle state of the Cloud FTP server (expected: ACTIVE)"
  value       = google_storage_ftp_server.managed_sftp.state
}

output "cloud_ftp_server_ip" {
  description = "Public IP address of the external Cloud FTP endpoint (SFTP, port 22)"
  value       = google_storage_ftp_server.managed_sftp.external_config[0].ip_address
}

output "cloud_ftp_service_agent" {
  description = "Email of the unique Service Agent generated automatically for this Cloud FTP server"
  value       = google_storage_ftp_server.managed_sftp.service_agent
}

output "configured_ftp_users" {
  description = "SFTP users: login username, provisioning state and backing service account"
  value = {
    for k, u in google_storage_ftp_user.managed_user :
    k => {
      username        = u.username
      state           = u.state
      service_account = google_service_account.ftp_user_sa[k].email
    }
  }
}

output "sftp_connection_commands" {
  description = "Ready-to-use SFTP commands per user (replace <private_key> with the path of the matching private key)"
  value = {
    for k, u in google_storage_ftp_user.managed_user :
    k => "sftp -i <private_key> ${u.username}@${google_storage_ftp_server.managed_sftp.external_config[0].ip_address}"
  }
}
