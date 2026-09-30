# Google Cloud FTP — Dual Authentication (GCP IAM & Microsoft Entra ID)

Configurazione Terraform completa e modulare per il deploy di un servizio **Cloud FTP** su Google Cloud, con storage centralizzato su **Google Cloud Storage (GCS)** e supporto a **doppia modalità di autenticazione**:

1. **GCP IAM Native (`enable_gcp_iam_auth = true`)**:
   - Utilizza il servizio nativo gestito **Cloud FTP** di Google Cloud (`google_storage_ftp_server` e `google_storage_ftp_user`).
   - Mappatura 1:1 di ciascun utente SFTP su una **GCP Service Account**.
   - Controllo accessi granulare tramite **Cloud IAM** (`roles/storage.objectUser`).
   - Autenticazione a **chiavi pubbliche SSH** (senza password, zero credenziali statiche memorizzate).

2. **Microsoft Entra ID (`enable_entra_id_auth = true`)**:
   - Consente agli utenti di connettersi via SFTP/FTP utilizzando **Username e Password aziendali**.
   - La verifica delle credenziali è **delegata al 100% a Microsoft Entra ID** (tramite OAuth2 ROPC / Microsoft Graph API).
   - In caso di esito positivo, l'utente viene isolato in chroot nella propria cartella su Cloud Storage (`gs://<bucket>/utenti/<username>/`).
   - Rotazione password, blocchi e policy di sicurezza sono gestiti centralmente su Microsoft Entra ID.

Entrambe le modalità possono essere abilitate **singolarmente** o **in contemporanea** sullo stesso bucket Cloud Storage.

---

## 📁 Struttura del Progetto

```text
.
├── .gitignore               # Esclude tfstate, credenziali e file sensibili
├── versions.tf              # Provider Google e Google-Beta (>= 6.3.0)
├── variables.tf             # Variabili e flag per abilitare IAM ed Entra ID
├── storage.tf               # Bucket Cloud Storage condiviso, versioning e lifecycle
├── cloud_ftp_iam.tf         # Server Cloud FTP nativo, Service Accounts e utenti SSH
├── cloud_ftp_entra_id.tf    # Gateway con validazione password su Microsoft Entra ID
├── outputs.tf               # Endpoint e istruzioni di connessione
├── terraform.tfvars.example # File di configurazione di esempio
└── README.md
```

---

## ⚙️ Quick Start

### 1. Configura le variabili
```bash
cp terraform.tfvars.example terraform.tfvars
```
Modifica `terraform.tfvars` indicando il tuo `project_id`, le chiavi SSH degli utenti IAM e/o i parametri di Microsoft Entra ID (`entra_tenant_id`, `entra_client_id`, `entra_client_secret`).

### 2. Deploy con Terraform
```bash
terraform init
terraform plan
terraform apply
```

---

## 🐙 Rilascio su GitHub

Per rilasciare questo codice sul tuo account GitHub **`Alessiozanfo`**:

```bash
cd /Users/zanforlin/.gemini/antigravity/scratch/terraform-cloud-ftp

# Collega il remote del repository GitHub prescelto (es. terraform-cloud-ftp)
git remote add origin git@github.com:Alessiozanfo/<nome-repo>.git
# oppure tramite HTTPS:
# git remote add origin https://github.com/Alessiozanfo/<nome-repo>.git

# Effettua il push del codice
git push -u origin main
```
