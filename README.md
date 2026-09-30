# Google Cloud FTP — Dual Authentication (GCP IAM & Microsoft Entra ID)

Configurazione Terraform completa e modulare per il deploy di un servizio **Cloud FTP** su Google Cloud, con storage centralizzato su **Google Cloud Storage (GCS)** e supporto a **doppia modalità di autenticazione**:

1. **GCP IAM Native (`enable_gcp_iam_auth = true`)**:
   - Utilizza il servizio nativo gestito **Cloud FTP** di Google Cloud (`google_storage_ftp_server` e `google_storage_ftp_user`).
   - Mappatura 1:1 di ciascun utente SFTP su una **GCP Service Account** (`customer_service_account`).
   - Mappatura della directory di destinazione con `storage_directory_mappings` su GCS.
   - Accesso del Service Agent dinamico (`service_agent`) autorizzato via IAM con `roles/iam.serviceAccountTokenCreator`.
   - Autenticazione a **chiavi pubbliche SSH** (`user_credentials`, zero credenziali statiche memorizzate).

2. **Microsoft Entra ID (`enable_entra_id_auth = true`)**:
   - Consente agli utenti di connettersi via SFTP/FTP utilizzando **Username e Password aziendali**.
   - La verifica delle credenziali è **delegata a Microsoft Entra ID** (tramite OAuth2 ROPC / Microsoft Graph API).
   - In caso di esito positivo, l'utente viene isolato in chroot nella propria cartella su Cloud Storage (`gs://<bucket>/utenti/<username>/`).
   - **Secret Manager**: il `client_secret` di Entra ID è protetto su Google Secret Manager (nessun secret in chiaro nei metadata di Compute Engine).
   - Supporto completo alle porte passive FTP (50000-50100) tramite network host.

Entrambe le modalità possono essere abilitate **singolarmente** o **in contemporanea** sullo stesso bucket Cloud Storage.

---

## 📁 Struttura del Progetto

```text
.
├── .gitignore               # Esclude tfstate, credenziali e file sensibili
├── versions.tf              # Provider Google e Google-Beta (>= 8.5.0)
├── variables.tf             # Variabili e flag per abilitare IAM ed Entra ID
├── storage.tf               # Bucket Cloud Storage condiviso, versioning e lifecycle
├── cloud_ftp_iam.tf         # Server Cloud FTP nativo, Service Accounts e utenti SSH
├── cloud_ftp_entra_id.tf    # Gateway con validazione password su Microsoft Entra ID e Secret Manager
├── outputs.tf               # Endpoint e istruzioni di connessione
├── terraform.tfvars.example # File di configurazione di esempio
└── README.md
```

---

## ⚠️ Note importanti su Microsoft Entra ID

* **Policy di MFA e Conditional Access**: Il flusso di validazione password usa OAuth2 ROPC (`grant_type=password`). Se sul tenant Entra ID sono attivi **Security Defaults** o policy di **Conditional Access** che impongono la MFA obbligatoria per tutti gli utenti, la richiesta fallirà con `interaction_required`.  
  *Raccomandazione*: Crea account utente dedicati al servizio SFTP o escludili dalle policy di MFA interattiva tramite gruppo di sicurezza in Conditional Access.

---

## ⚙️ Quick Start

### 1. Prerequisiti
* Terraform `>= 1.5.0`
* Google Cloud Provider `>= 8.5.0`

### 2. Configura le variabili
```bash
cp terraform.tfvars.example terraform.tfvars
```
Modifica `terraform.tfvars` indicando il tuo `project_id`, le chiavi SSH degli utenti IAM e/o i parametri di Microsoft Entra ID (`entra_tenant_id`, `entra_client_id`, `entra_client_secret`).

### 3. Deploy con Terraform
```bash
terraform init
terraform plan
terraform apply
```

---

## 🐙 Repository GitHub

Repository remoto collegato:
👉 **[https://github.com/Alessiozanfo/terraform-cloud-ftp](https://github.com/Alessiozanfo/terraform-cloud-ftp)**
