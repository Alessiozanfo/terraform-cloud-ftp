# Ruolo IAM per il logging CloudWatch di AWS Transfer Server
resource "aws_iam_role" "transfer_logging" {
  name = "${var.server_name}-logging-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transfer_logging" {
  role       = aws_iam_role.transfer_logging.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSTransferLoggingAccess"
}

# Ruolo IAM per gli utenti FTP (accesso a S3)
resource "aws_iam_role" "transfer_user" {
  name = "${var.server_name}-user-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy per limitare gli utenti FTP alle sole operazioni necessarie su S3
resource "aws_iam_policy" "transfer_user_s3_policy" {
  name        = "${var.server_name}-s3-access-${var.environment}"
  description = "Permessi S3 per utenti AWS Transfer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.ftp_storage.arn
      },
      {
        Sid    = "AllowObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectVersion",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ]
        Resource = "${aws_s3_bucket.ftp_storage.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transfer_user_s3_attach" {
  role       = aws_iam_role.transfer_user.name
  policy_arn = aws_iam_policy.transfer_user_s3_policy.arn
}
