# Google Cloud FTP — Native Managed SFTP with Terraform

Complete, production-ready Terraform configuration for deploying a 100% native, serverless **Cloud FTP** service managed directly by Google Cloud, backed by **Google Cloud Storage (GCS)**, with enterprise lifecycle integration via **Microsoft Entra ID (Azure AD)**.

Zero Compute Engine VMs, zero Docker containers, and no third-party software (such as SFTPGo) to patch, monitor, or maintain.

---

## 🏛️ Enterprise Architecture: Cloud FTP + Microsoft Entra ID

For organizations using directory federation between **Microsoft Entra ID** (as the *Single Source of Truth*) and **Google Cloud Identity** (via Google Workspace / Google Admin SCIM sync), this architecture provides seamless governance and strong security:

```
[ Microsoft Entra ID ]  (Single Source of Truth for Enterprise Identities)
          |
          |  (Automatic SCIM User Sync / Provisioning)
          v
[ Google Cloud Identity ]
          |
          |  (IAM Role Assignments & Service Accounts)
          v
[ Google Cloud FTP (Native Serverless) ] <=====> [ Google Cloud Storage ]
          ^
          |  (Port 22 SFTP connection with Corporate SSH Key)
          |
    [ SFTP Client ] (FileZilla, WinSCP, Cyberduck, CI/CD scripts)
```

### 🔐 How the Integration Works in Practice

1. **Centralized Identity Lifecycle on Microsoft Entra ID**:
   - When an employee or external partner is onboarded or assigned to the SFTP security group in Entra ID, existing SCIM sync automatically provisions them in Google Cloud Identity (`john.doe@company.com`).
   - When a user leaves the company or is disabled in Entra ID, the sync immediately disables their Google account: **access to Cloud FTP and Cloud Storage is revoked instantly**.
2. **Cryptographically Strong Authentication (Zero Passwords)**:
   - Google Cloud FTP enforces enterprise security baselines (CIS, NIST): **it disallows static password authentication** and strictly requires **SSH key pairs** (Ed25519 or RSA).
   - The user generates their SSH key pair, and the administrator (or Terraform pipeline) associates the public key with the Cloud FTP user resource.

---

## 💡 Why SSH Keys are Superior to Entering Passwords in SFTP Clients

Stakeholders occasionally ask: *"If we have Microsoft Entra ID, why can't users type their Office 365 password directly into FileZilla?"*.

Here is why entering identity passwords into legacy SFTP clients is a critical **security anti-pattern**:
* **Protocol Limitations**: SFTP (port 22) is a binary file transfer protocol: **it cannot perform browser redirects, modern web login modals, push-based MFA (Microsoft Authenticator app), or Conditional Access evaluations**.
* **Compromised Security Posture**: In order to allow an SFTP client to validate passwords against Entra ID, an organization would have to bypass MFA and Security Defaults for those accounts, leaving them vulnerable to brute-force and credential-stuffing attacks.
* **The Native Cloud FTP Solution**: With SSH keys, connections are cryptographically secure, while **governance, role assignment, and access lifecycle remain 100% controlled by Microsoft Entra ID**.

---

## 📁 Repository Structure

```text
.
├── .gitignore               # Excludes tfstate, local credentials, and sensitive files
├── versions.tf              # Google and Google-Beta provider definitions (>= 8.5.0)
├── variables.tf             # Project, region, and SFTP user definitions
├── storage.tf               # Cloud Storage bucket with Uniform Access and lifecycle policies
├── cloud_ftp.tf             # Native Cloud FTP server, IAM Service Accounts, Service Agent, and Users
├── outputs.tf               # Server ID, Service Agent email, and SFTP connection syntax
├── terraform.tfvars.example # Example configuration file
└── README.md                # Architectural documentation and deployment guide
```

---

## ⚙️ Terraform Components Detailed

### 1. [cloud_ftp.tf](cloud_ftp.tf)
* **`google_storage_ftp_server`**: Managed native resource exposing the external SFTP endpoint with configurable IP filtering (`allowed_cidr_blocks`).
* **`google_service_account`**: Provisions a dedicated application Service Account for each SFTP user.
* **`google_service_account_iam_member`**: Automatically binds `roles/iam.serviceAccountTokenCreator` to the unique server-generated Cloud FTP Service Agent (`google_storage_ftp_server.managed_sftp.service_agent`).
* **`google_storage_ftp_user`**: Registers the user on the server, maps their root directory (`/incoming`) to an isolated GCS prefix (`incoming/<user_id>`), and assigns authorized SSH public keys (`user_credentials`).

### 2. [storage.tf](storage.tf)
* **`google_storage_bucket`**: Dedicated storage bucket with `uniform_bucket_level_access = true`, versioning enabled, and automated lifecycle rules to transition older files to Nearline storage.

---

## 🚀 Deployment Instructions

### 1. Prerequisites
* [Terraform](https://www.terraform.io/downloads.html) `>= 1.5.0`
* Google Cloud Provider `>= 8.5.0`
* IAM permissions on the GCP project: `roles/storage.admin`, `roles/resourcemanager.projectIamAdmin`, `roles/iam.serviceAccountAdmin`.

### 2. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` with your `project_id`, `cloud_ftp_server_id`, and the authorized SSH public keys for your users.

### 3. Deploy with Terraform
```bash
terraform init
terraform plan
terraform apply
```

### 4. User Connection
Once deployed, users can connect using standard SFTP clients (OpenSSH, FileZilla, Cyberduck, WinSCP):

```bash
sftp -i ~/.ssh/id_ed25519 partner_alpha@<SERVER_HOST_OR_IP>
```
*(In graphical clients like FileZilla, leave the password field **empty** and configure the private SSH key).*
