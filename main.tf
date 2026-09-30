# AWS Transfer Family Server (SFTP / FTPS / FTP)
resource "aws_transfer_server" "ftp_server" {
  identity_provider_type = "SERVICE_MANAGED"
  protocols              = var.protocols
  endpoint_type          = var.endpoint_type
  logging_role           = aws_iam_role.transfer_logging.arn

  tags = {
    Name = var.server_name
  }
}

# Utenti Transfer Family (creati dinamicamente dalla variabile ftp_users)
resource "aws_transfer_user" "ftp_user" {
  for_each = var.ftp_users

  server_id      = aws_transfer_server.ftp_server.id
  user_name      = each.key
  role           = aws_iam_role.transfer_user.arn
  
  # Struttura Directory Logica (Chroot jail): l'utente vede come root "/" la propria cartella S3
  home_directory_type = "LOGICAL"

  home_directory_mappings {
    entry  = "/"
    target = "/${aws_s3_bucket.ftp_storage.id}/${each.key}"
  }

  tags = {
    Name = each.key
  }
}

# Associazione delle chiavi pubbliche SSH agli utenti per autenticazione sicura SFTP
resource "aws_transfer_ssh_key" "user_key" {
  for_each = var.ftp_users

  server_id = aws_transfer_server.ftp_server.id
  user_name = aws_transfer_user.ftp_user[each.key].user_name
  body      = trimspace(each.value.ssh_public_key)
}
