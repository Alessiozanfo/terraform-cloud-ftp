terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # In caso di salvataggio dello stato su remoto (S3 + DynamoDB per il lock):
  # backend "s3" {
  #   bucket         = "mio-terraform-state-bucket"
  #   key            = "cloud-ftp/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "Cloud-FTP"
    }
  }
}
