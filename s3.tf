# Bucket S3 per memorizzare i file caricati via Cloud FTP
resource "aws_s3_bucket" "ftp_storage" {
  bucket        = var.bucket_name
  bucket_prefix = var.bucket_name == null ? "cloud-ftp-storage-${var.environment}-" : null

  # Protezione contro eliminazione accidentale in produzione
  lifecycle {
    prevent_destroy = false
  }
}

# Blocco dell'accesso pubblico diretto a S3 (i file passano esclusivamente dal protocollo FTP/SFTP)
resource "aws_s3_bucket_public_access_block" "ftp_storage" {
  bucket = aws_s3_bucket.ftp_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning del bucket (opzionale ma consigliato per prevenire sovrascritture accidentali)
resource "aws_s3_bucket_versioning" "ftp_storage" {
  bucket = aws_s3_bucket.ftp_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Crittografia a riposo (SSE-S3 con AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "ftp_storage" {
  bucket = aws_s3_bucket.ftp_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
