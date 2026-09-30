# Google Cloud FTP — Native Managed SFTP with Terraform

Configurazione Terraform completa per il deploy di un servizio **Cloud FTP** 100% nativo, serverless e gestito direttamente da Google Cloud, con storage persistente su **Google Cloud Storage (GCS)** e integrazione enterprise con **Microsoft Entra ID (Azure AD)**.

Nessuna macchina virtuale Compute Engine, nessun container Docker e nessuna applicazione terza (come SFTPGo) da gestire, patchare o monitorare.

---

## 🏛️ Architettura Enterprise: Cloud FTP + Microsoft Entra ID

Dato che l'organizzazione adotta la federazione tra **Microsoft Entra ID** (come *Single Source of Truth*) e **Google Cloud Identity** (tramite Google Admin Console / SCIM sync), l'architettura opera in modo armonico e sicuro:

```
[ Microsoft Entra ID ]  (Single Source of Truth delle Identità Aziendali)
          |
          |  (Sincronizzazione automatica SCIM / Provisioning utenti)
          v
[ Google Cloud Identity ]
          |
          |  (Assegnazione permessi IAM e Service Account)
          v
[ Google Cloud FTP (Nativo Serverless) ] <=====> [ Google Cloud Storage ]
          ^
          |  (Connessione SFTP porta 22 con Chiave SSH aziendale)
          |
    [ Client SFTP ] (FileZilla, WinSCP, Cyberduck, script CI/CD)
```

### 🔐 Come opera l'integrazione nella pratica

1. **Ciclo di Vita centralizzato su Entra ID**:
   - Quando un dipendente o un partner viene creato o assegnato al gruppo SFTP su Entra ID, la sincronizzazione SCIM già attiva lo crea automaticamente in Google Cloud Identity (`mario.rossi@azienda.com`).
   - Se l'utente lascia l'azienda o viene disattivato su Entra ID, la disattivazione si riflette immediatamente in Google: **l'accesso al Cloud FTP e ai bucket GCS viene revocato all'istante**.
2. **Autenticazione Crittografica Forte (Zero-Password)**:
   - Cloud FTP adotta gli standard di sicurezza CIS e NIST: **rifiuta l'uso di password statiche** e impone l'uso di **coppie di chiavi SSH** (Ed25519 o RSA).
   - L'utente genera la propria chiave SSH e l'amministratore (o la pipeline Terraform) la associa all'utente Cloud FTP.

---

## 💡 Perché la Chiave SSH è Superiore all'inserimento Password in FileZilla

Spesso i team non tecnici chiedono: *"Se abbiamo Entra ID, perché l'utente non può digitare la password di Office 365 dentro FileZilla?"*.

Ecco i motivi tecnici e di sicurezza per cui la password in FileZilla è un grave **anti-pattern di sicurezza**:
* **Incompatibilità di Protocollo**: Il protocollo SFTP (porta 22) è un protocollo di trasporto file binario a riga di comando: **non supporta redirect browser, finestre di login web, MFA con notifica push (Microsoft Authenticator) o Conditional Access**.
* **Abbassamento della Sicurezza**: Per consentire a un client SFTP di inviare una password di Entra ID, l'azienda dovrebbe disabilitare la MFA e i Security Defaults per quegli account su Entra ID, esponendo l'azienda ad attacchi brute-force o phishing.
* **La Soluzione di Cloud FTP**: Con le chiavi SSH, la connessione è crittograficamente inviolabile, mentre **la governance, i ruoli e la permanenza in azienda rimangono al 100% governati da Microsoft Entra ID**.

---

## 📁 Struttura del Repository

```text
.
├── .gitignore               # Esclude tfstate, credenziali locali e file sensibili
├── versions.tf              # Provider Google e Google-Beta (>= 8.5.0)
├── variables.tf             # Variabili di progetto, regione e mappa utenti SFTP
├── storage.tf               # Bucket Cloud Storage con Uniform Access, lifecycle e crittografia
├── cloud_ftp.tf             # Server Cloud FTP nativo, Service Account IAM, Service Agent e Utenti
├── outputs.tf               # ID del server, Service Agent e sintassi di connessione SFTP
├── terraform.tfvars.example # File di configurazione di esempio
└── README.md                # Documentazione architetturale e operativa
```

---

## ⚙️ Componenti Terraform Dettagliati

### 1. [cloud_ftp.tf](cloud_ftp.tf)
* **`google_storage_ftp_server`**: Risorsa nativa gestita che espone l'endpoint SFTP esterno con blocco IP configurabile (`allowed_cidr_blocks`).
* **`google_service_account`**: Crea la Service Account applicativa dedicata a ciascun utente.
* **`google_service_account_iam_member`**: Assegna automaticamente `roles/iam.serviceAccountTokenCreator` al Service Agent univoco generato da Cloud FTP (`google_storage_ftp_server.managed_sftp.service_agent`).
* **`google_storage_ftp_user`**: Registra l'utente sul server, configura il mapping della directory (`/incoming`) isolando ciascun utente sul prefisso GCS (`incoming/<user_id>`) e registra le chiavi pubbliche SSH autorizzate (`user_credentials`).

### 2. [storage.tf](storage.tf)
* **`google_storage_bucket`**: Bucket dedicato con `uniform_bucket_level_access = true`, versioning abilitato e lifecycle rules per la transizione verso classi di storage a costo inferiore.

---

## 🚀 Istruzioni di Deploy

### 1. Prerequisiti
* [Terraform](https://www.terraform.io/downloads.html) `>= 1.5.0`
* Provider Google / Google-Beta `>= 8.5.0`
* Permessi IAM sul progetto GCP: `roles/storage.admin`, `roles/resourcemanager.projectIamAdmin`, `roles/iam.serviceAccountAdmin`.

### 2. Configura le variabili
```bash
cp terraform.tfvars.example terraform.tfvars
```
Modifica `terraform.tfvars` inserendo il tuo `project_id`, il `cloud_ftp_server_id` e le chiavi pubbliche SSH degli utenti da abilitare.

### 3. Esegui Terraform
```bash
terraform init
terraform plan
terraform apply
```

### 4. Connessione Utente
Una volta completato il deploy, l'utente può collegarsi con qualsiasi client compatibile SFTP (OpenSSH, FileZilla, Cyberduck, WinSCP):

```bash
sftp -i ~/.ssh/id_ed25519 partner_alpha@<IP_O_DNS_DEL_SERVER>
```
*(Nel client grafico, lasciare il campo password **vuoto** e selezionare la chiave privata SSH).*
