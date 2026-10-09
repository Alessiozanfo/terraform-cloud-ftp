variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "The Google Cloud region to deploy resources into. Cloud FTP is available only in a subset of regions (europe-west1 is one of them): check the Cloud FTP locations documentation before changing it."
  type        = string
  default     = "europe-west1"
}

variable "bucket_name" {
  description = "Unique name for the Cloud Storage bucket. If null, defaults to '<project_id>-cloud-ftp-storage'. The bucket must live in the same project as the Cloud FTP server (enforced by the API)."
  type        = string
  default     = null
}

variable "cloud_ftp_server_id" {
  description = "ID of the managed Cloud FTP server. Must start with a lowercase letter, end with a lowercase letter or digit, contain only lowercase letters, digits and hyphens, max 30 characters."
  type        = string
  default     = "partner-sftp-srv"

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9-]{0,28}[a-z0-9])?$", var.cloud_ftp_server_id))
    error_message = "cloud_ftp_server_id must match ^[a-z](?:[a-z0-9-]{0,28}[a-z0-9])?$ (max 30 characters)."
  }
}

variable "allowed_cidr_blocks" {
  description = "List of IPv4 CIDR blocks authorized to connect to the external Cloud FTP server. This allowlist is the ONLY network-level control of an EXTERNAL server: always restrict it to the partners' egress IPs. 0.0.0.0/0 is rejected on purpose."
  type        = list(string)

  validation {
    condition = (
      length(var.allowed_cidr_blocks) > 0 &&
      length(var.allowed_cidr_blocks) <= 500 &&
      !contains(var.allowed_cidr_blocks, "0.0.0.0/0") &&
      alltrue([
        for c in var.allowed_cidr_blocks :
        can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$", c)) && can(cidrhost(c, 0))
      ])
    )
    error_message = "allowed_cidr_blocks must contain 1-500 valid IPv4 CIDR blocks (Cloud FTP currently supports IPv4 only) and must not include 0.0.0.0/0."
  }
}

variable "labels" {
  description = "Optional key-value labels to apply to Cloud FTP resources"
  type        = map(string)
  default     = {}
}

variable "ftp_users" {
  description = <<-EOT
    Map of native SFTP users. The map key is both the Cloud FTP user_id (the SFTP
    login name) and the suffix of the dedicated service account (ftp-usr-<key>),
    so it must satisfy the stricter service-account naming rules:
    lowercase letters, digits and hyphens, starting with a letter, 1-22 characters.
    Each user needs 1-10 OpenSSH public keys (ssh-ed25519 or ssh-rsa); prefer
    file("path/to/key.pub") over inline literals.
  EOT
  type = map(object({
    ssh_public_keys = list(string)
    display_name    = optional(string)
    bucket_prefix   = optional(string)
    directory       = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, _ in var.ftp_users : can(regex("^[a-z][a-z0-9-]{0,21}$", k))
    ])
    error_message = "ftp_users keys must match ^[a-z][a-z0-9-]{0,21}$ so that the derived service account ID (ftp-usr-<key>) is a valid 6-30 character RFC1035 name. Underscores are not allowed."
  }

  validation {
    condition = alltrue([
      for k, _ in var.ftp_users :
      !contains(["root", "daemon", "bin", "sys", "adm", "mail", "nobody", "ftp", "sshd", "guest"], k)
    ])
    error_message = "ftp_users keys must not be standard system account names (root, daemon, ftp, nobody, ...): the Cloud FTP API rejects reserved usernames."
  }

  validation {
    condition = alltrue([
      for _, u in var.ftp_users :
      length(u.ssh_public_keys) >= 1 && length(u.ssh_public_keys) <= 10 &&
      alltrue([
        for key in u.ssh_public_keys :
        can(regex("^(ssh-ed25519|ssh-rsa) [A-Za-z0-9+/]+={0,3}( [^\\s]+)?\\s*$", key))
      ])
    ])
    error_message = "Each user needs 1-10 ssh_public_keys in OpenSSH authorized_keys format (ssh-ed25519 or ssh-rsa) with no options prefix."
  }

  validation {
    condition = alltrue([
      for _, u in var.ftp_users :
      (u.bucket_prefix == null || can(regex("^[A-Za-z0-9_/-]*$", u.bucket_prefix))) &&
      (u.directory == null || can(regex("^/[A-Za-z0-9_/-]*$", u.directory)))
    ])
    error_message = "bucket_prefix may contain only [A-Za-z0-9_/-]; directory must start with '/' and contain only [A-Za-z0-9_/-]."
  }
}
