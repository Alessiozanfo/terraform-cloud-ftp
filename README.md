# Cloud FTP / SFTP Server with Terraform

Modulo Terraform pronto per la produzione per il deploy di un servizio **Cloud FTP / SFTP** completamente gestito (senza server da gestire o patchare), basato su **AWS Transfer Family** e storage sicuro su **Amazon S3**.

---

## 🚀 Architettura

- **AWS Transfer Family**: Endpoint gestito scalabile e ad alta disponibilità che supporta i protocolli `SFTP`, `FTPS` e `FTP`.
- **Amazon S3 Bucket**: Storage persistente con crittografia a riposo (AES-256), blocco accesso pubblico e versioning opzionale.
- **IAM & Directory Chroot**: Ciascun utente è isolato nella propria sottocartella S3 (`/nome-utente`) tramite mappatura logica (`LOGICAL`), impedendo la navigazione nei file degli altri utenti.
- **CloudWatch Logs**: Tracciamento di accessi, comandi e trasferimenti file.

---

## 📁 Struttura File

```text
.
├── .gitignore               # Ignora chiavi, tfstate e file sensibili
├── versions.tf              # Configurazione provider e versioni
├── variables.tf             # Variabili di configurazione
├── s3.tf                    # Bucket S3 cifrato e sicuro
├── iam.tf                   # Ruoli e policy IAM (logging e accesso scoped S3)
├── main.tf                  # Risorse AWS Transfer Server e Utenti
├── outputs.tf               # Endpoint del server e info di connessione
├── terraform.tfvars.example # Esempio di valorizzazione variabili
└── README.md
```

---

## ⚙️ Quick Start

### 1. Prerequisiti
- [Terraform >= 1.5.0](https://www.terraform.io/downloads.html)
- AWS CLI configurata con credenziali appropriate (`aws configure`)

### 2. Configura le variabili
Copia il file di esempio e personalizzalo:
```bash
cp terraform.tfvars.example terraform.tfvars
```
Genera una coppia di chiavi SSH per ciascun utente (se non ne possiedi già):
```bash
ssh-keygen -t ed25519 -f ./id_ftp_partner -C "partner_alpha"
```
Inserisci la chiave pubblica `.pub` dentro `terraform.tfvars`.

### 3. Deploy
```bash
terraform init
terraform plan
terraform apply
```

### 4. Connessione
Al termine del deploy, Terraform restituirà l'endpoint del server. Potrai collegarti con:
```bash
sftp -i ./id_ftp_partner partner_alpha@<server_endpoint>
```

---

## 🐙 Pubblicazione su GitHub

Quando avrai deciso il nome del repository GitHub:

```bash
# Inizializza git
git init
git add .
git commit -m "feat: initial commit cloud ftp terraform config"

# Rinomina il branch in main
git branch -M main

# Collega il remote GitHub e fai il push
git remote add origin git@github.com:<tuo-utente-o-org>/<tuo-repo>.git
git push -u origin main
```
