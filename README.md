# Google Cloud FTP — Native Managed SFTP with Terraform

Terraform configuration for deploying a 100% native, serverless **Cloud FTP** service managed directly by Google Cloud, backed by **Google Cloud Storage (GCS)**, with one dedicated service account and isolated bucket prefix per SFTP user.

Zero Compute Engine VMs, zero Docker containers, and no third-party software (such as SFTPGo) to patch, monitor, or maintain.

---

## 🏛️ Architecture

```
[ SFTP Client ] (FileZilla, WinSCP, Cyberduck, CI/CD scripts)
      |
      |  SFTP (port 22) — SSH public-key authentication, IPv4 allowlist
      v
[ Google Cloud FTP server (EXTERNAL, native serverless) ]
      |
      |  Cloud FTP service agent impersonates the user's service account
      |  (roles/iam.serviceAccountTokenCreator)
      v
[ ftp-usr-<user> service account ] --(roles/storage.objectUser)--> [ GCS bucket / incoming/<user>/ ]
```

### How authentication and authorization work

1. **Authentication — SSH keys only.** Cloud FTP does not support password authentication: every user is created with 1–10 OpenSSH public keys (`ssh-ed25519` or `ssh-rsa`). The matching private key stays with the partner.
2. **Authorization — one service account per user.** Each `google_storage_ftp_user` is bound to a dedicated service account (`ftp-usr-<user>`) that holds `roles/storage.objectUser` on the bucket. The server's service agent is allowed to impersonate it (`roles/iam.serviceAccountTokenCreator`), so every object operation is performed *as that service account* and audited as such.
3. **Isolation — one prefix per user.** The user's virtual root (`/incoming`) is mapped to `incoming/<user>/` in the bucket; users cannot see each other's prefixes.
4. **Network — IPv4 allowlist.** `allowed_cidr_blocks` is the only network-level control of an `EXTERNAL` server. This configuration refuses `0.0.0.0/0`; use an `INTERNAL` (Private Service Connect) server if partners can reach you over private connectivity.

> [!IMPORTANT]
> **Identity governance (Microsoft Entra ID / Cloud Identity).** SFTP users are *not* linked to human identities: access is granted by the SSH key and the service account, not by a Google account. Disabling a person in Entra ID or Cloud Identity therefore **does not** revoke their SFTP access. Revocation happens when the entry is removed from `ftp_users` (or its key is rotated) and `terraform apply` is run. If you need lifecycle automation, drive the `ftp_users` map from your source of truth (e.g. a Cloud Identity group synced from Entra ID) and run the pipeline on a schedule or on group-change events.

### Why SSH keys instead of directory passwords

Stakeholders occasionally ask: *"If we have Microsoft Entra ID, why can't users type their Office 365 password directly into FileZilla?"*

* **Protocol limitations**: SFTP is a binary file-transfer protocol over SSH; it cannot perform browser redirects, modern login modals, push-based MFA, or Conditional Access evaluations.
* **Security posture**: letting a legacy SFTP client validate passwords against the directory would require bypassing MFA for those accounts, exposing them to brute-force and credential-stuffing attacks.
* **Native Cloud FTP model**: SSH keys give cryptographically strong, non-interactive authentication, while every data-plane operation is still attributed to a Google Cloud service account that you control through IAM.

---

## 📁 Repository Structure

```text
.
├── .gitignore               # Excludes tfstate, local credentials, and sensitive files
├── versions.tf              # Terraform and Google provider requirements (>= 8.5.0, < 9.0.0)
├── variables.tf             # Inputs with validation (naming rules, CIDRs, SSH key format)
├── storage.tf               # Cloud Storage bucket with uniform access, versioning and lifecycle rules
├── cloud_ftp.tf             # Cloud FTP server, per-user service accounts, IAM bindings and users
├── outputs.tf               # Endpoint IP, server/user states, ready-to-use connection commands
├── terraform.tfvars.example # Example configuration file
└── README.md                # Architectural documentation and deployment guide
```

---

## ⚙️ Terraform Components Detailed

### 1. [cloud_ftp.tf](cloud_ftp.tf)
* **`google_storage_ftp_server`**: managed `EXTERNAL` server with IPv4 allowlisting (`allowed_cidr_blocks`). Exposes `service_agent`, `state` and `external_config[0].ip_address`.
* **`google_service_account`**: one dedicated service account per SFTP user (`ftp-usr-<user>`).
* **`google_storage_bucket_iam_member`**: grants `roles/storage.objectUser` on the bucket to each user service account (covers every permission the Cloud FTP data plane needs for `READ_WRITE` mappings, including hierarchical-namespace folders, without object ACL/IAM administration).
* **`google_service_account_iam_member`**: binds `roles/iam.serviceAccountTokenCreator` on each user service account to the server-generated Cloud FTP service agent.
* **`google_storage_ftp_user`**: registers the user, maps `/incoming` to `incoming/<user>` and assigns the authorized SSH public keys (`user_credentials`).

### 2. [storage.tf](storage.tf)
* **`google_storage_bucket`**: `uniform_bucket_level_access`, `public_access_prevention = "enforced"`, versioning, Nearline transition after 90 days and pruning of noncurrent versions (keeps the 3 most recent).

### Naming constraints

| Input | Rule | Why |
|---|---|---|
| `ftp_users` keys | `^[a-z][a-z0-9-]{0,21}$`, not a reserved system username (`root`, `ftp`, `mail`, …) | The key is the SFTP login name **and** the suffix of the service account ID `ftp-usr-<key>`, which must be a 6–30 character RFC1035 name (no underscores) |
| `cloud_ftp_server_id` | `^[a-z](?:[a-z0-9-]{0,28}[a-z0-9])?$` | Cloud FTP API constraint (max 30 characters) |
| `ssh_public_keys` | 1–10 keys, OpenSSH format, `ssh-ed25519` or `ssh-rsa` | Cloud FTP API constraint; prefer `file("key.pub")` to inline literals |
| `allowed_cidr_blocks` | 1–500 IPv4 CIDRs, `0.0.0.0/0` rejected | Cloud FTP supports IPv4 allowlists only; the allowlist is the sole network control |

All of the above are enforced by `validation` blocks at `terraform plan` time instead of surfacing minutes later as API errors during `apply`.

---

## 🚀 Deployment Instructions

### 1. Prerequisites
* [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.5.0`
* Google Cloud provider `>= 8.5.0`
* A region where Cloud FTP is available (e.g. `europe-west1`).
* IAM roles on the project for the identity running `terraform apply`:

  | Role | Needed for |
  |---|---|
  | `roles/ftp.admin` | Creating the Cloud FTP server and users |
  | `roles/storage.admin` | Bucket creation, bucket IAM bindings and the `storage.buckets.get` check performed by the Cloud FTP API |
  | `roles/iam.serviceAccountAdmin` | Creating the per-user service accounts and setting their IAM policy |
  | `roles/iam.serviceAccountUser` | The Cloud FTP API verifies that the caller can act as (`iam.serviceAccounts.actAs`) each `customer_service_account` before creating a user; grant it on the `ftp-usr-*` service accounts (or project-wide) |
  | `roles/serviceusage.serviceUsageAdmin` | Enabling `ftp.googleapis.com`, `storage.googleapis.com` and `iam.googleapis.com` |

### 2. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` with your `project_id`, the partners' egress IPs in `allowed_cidr_blocks`, and the real SSH public keys of your users.

### 3. Deploy with Terraform
```bash
terraform init
terraform plan
terraform apply
```
Server creation is a long-running operation (several minutes). When it completes, `terraform output` shows the endpoint IP, the server/user states and a ready-to-use command per user:

```bash
terraform output cloud_ftp_server_ip
terraform output sftp_connection_commands
```

### 4. User Connection
Users connect with any standard SFTP client (OpenSSH, FileZilla, Cyberduck, WinSCP) using the login name shown in `configured_ftp_users` and the IP in `cloud_ftp_server_ip`:

```bash
sftp -i ~/.ssh/partner_alpha partner-alpha@<cloud_ftp_server_ip>
```
*(In graphical clients such as FileZilla, leave the password field **empty** and configure the private SSH key.)*

### 5. Offboarding a user
Remove the entry from `ftp_users` and run `terraform apply`: the Cloud FTP user, its IAM bindings and its service account are deleted. Files already uploaded under `incoming/<user>/` are left in the bucket.
