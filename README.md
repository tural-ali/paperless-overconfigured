# Paperless Overconfigured

[![CI](https://github.com/tural-ali/paperless-overconfigured/actions/workflows/ci.yml/badge.svg)](https://github.com/tural-ali/paperless-overconfigured/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/tural-ali/paperless-overconfigured)](https://github.com/tural-ali/paperless-overconfigured/releases)

> A production-ready, AI-powered document management stack. One command. A few questions. Stack running.

Paperless-NGX with batteries included: AI classification, automated backups, ASN barcode tracking, secure remote access, and blank page removal. Everything configured with best practices out of the box.

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tural-ali/paperless-overconfigured/main/install.sh)
```

The installer will:
1. Detect your OS and install dependencies
2. Walk you through configuration (access method, AI provider, backups, etc.)
3. Generate all config files and start the stack
4. Set up automated backups if you choose

<details>
<summary><b>See the installer in action</b></summary>

```
  ██████╗  █████╗ ██████╗ ███████╗██████╗ ██╗     ███████╗███████╗███████╗
  ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗██║     ██╔════╝██╔════╝██╔════╝
  ██████╔╝███████║██████╔╝█████╗  ██████╔╝██║     █████╗  ███████╗███████╗
  ██╔═══╝ ██╔══██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══╝  ╚════██║╚════██║
  ██║     ██║  ██║██║     ███████╗██║  ██║███████╗███████╗███████║███████║
  ╚═╝     ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝
                         OVERCONFIGURED

  A production-ready, AI-powered document management stack.
  Paperless-NGX + AI classification + automated backups.

[OK] Detected: debian (amd64)

This installer will:
  1. Install dependencies (Docker, etc.)
  2. Ask you a few questions to configure the stack
  3. Generate all config files
  4. Start the Paperless-NGX stack
  5. Optionally set up backups and remote access

[1/8] Installation Directory
Where should Paperless be installed?
  Path [/home/user/paperless]: ▌

[2/8] Admin Credentials
  Username [admin]: ▌
  Password: ••••••••

[3/8] Access Method
How will you access Paperless remotely?
  1) Tailscale — private mesh network (recommended)
  2) Cloudflare Tunnel — public domain, behind Cloudflare
  3) Both Tailscale + Cloudflare Tunnel
  4) Local only — localhost access, no remote
  5) Direct expose — open port to internet (not recommended)
Enter choice [1-5]: ▌

[4/8] AI-Powered Classification
Choose your LLM provider for automatic document classification:
  1) Google AI (Gemini) — fast and affordable
  2) OpenAI (GPT-4o) — high accuracy
  3) Ollama — local LLM, no API costs
  4) Skip — no AI classification
Enter choice [1-4]: ▌

[5/8] OCR Languages
  1) English only
  2) German + English
  3) Custom (enter Tesseract language codes)
Enter choice [1-3]: ▌

[6/8] Timezone
  Detected: Europe/Berlin
  Timezone [Europe/Berlin]: ▌

[7/8] Automated Backups
  1) Google Drive
  2) Dropbox
  3) OneDrive
  4) Encrypted to GitHub
  5) Custom rclone remote
  6) Local backups only
  7) Skip — no backups
Enter choice [1-7]: ▌

[8/8] Review & Confirm
  ┌─────────────────────────────────────┐
  │ Install dir:  /home/user/paperless  │
  │ Admin:        admin                 │
  │ Access:       Tailscale             │
  │ AI:           Google AI (Gemini)    │
  │ OCR:          English               │
  │ Timezone:     Europe/Berlin         │
  │ Backups:      Google Drive          │
  └─────────────────────────────────────┘

  ╔══════════════════════════════════════════════════╗
  ║   Paperless Overconfigured is running!           ║
  ╚══════════════════════════════════════════════════╝

  Services:
    paperless-ngx: Up (healthy)
    paperless-gpt: Up (healthy)
    postgres: Up (healthy)
    redis: Up (healthy)
    gotenberg: Up (healthy)
    tika: Up (healthy)

  Access:
    Paperless: https://my-server:8000

  Admin: admin / (your password)
```

</details>

## Architecture

```mermaid
graph TB
    subgraph Access["Remote Access"]
        TS["Tailscale<br/><i>Private network</i>"]
        CF["Cloudflare Tunnel<br/><i>Public domain</i>"]
    end

    subgraph Stack["Docker Stack"]
        direction TB
        P["Paperless-NGX<br/>Document Management"]
        GPT["paperless-gpt<br/><i>AI Classification</i>"]
        DB[("PostgreSQL<br/>Database")]
        Redis[("Redis<br/>Cache & Queue")]
        Gotenberg["Gotenberg<br/>Document Conversion"]
        Tika["Apache Tika<br/>Text Extraction"]
    end

    subgraph AI["LLM Provider"]
        Gemini["Google Gemini"]
        OpenAI["OpenAI GPT"]
        Ollama["Ollama<br/><i>Local LLM</i>"]
    end

    subgraph Backup["Automated Backups"]
        GDrive["Google Drive"]
        Dropbox["Dropbox"]
        OneDrive["OneDrive"]
        GitHub["GitHub<br/><i>Encrypted</i>"]
    end

    subgraph Input["Document Input"]
        Scanner["Scanner"]
        Email["Email"]
        Upload["Web Upload"]
        Mobile["Mobile App"]
    end

    TS --> P
    CF --> P
    P --> DB
    P --> Redis
    P --> Gotenberg
    P --> Tika
    GPT --> P
    GPT --> Gemini
    GPT --> OpenAI
    GPT --> Ollama
    Scanner --> GDrive
    GDrive --> P
    Email --> P
    Upload --> P
    Mobile --> P
    P --> Backup
```

## What's Included

| Feature | Description |
|---------|-------------|
| **Paperless-NGX** | Core document management with full-text search, tagging, correspondents |
| **AI Classification** | Automatic title, tags, correspondent, document type via LLM (Gemini/GPT/Ollama) |
| **ASN Barcode Tracking** | Physical filing system with QR code labels and fallback OCR detection |
| **Blank Page Removal** | Automatically strips blank pages from scanned PDFs before import |
| **Automated Backups** | Daily/weekly/monthly rotation to Google Drive, Dropbox, OneDrive, or encrypted GitHub |
| **Secure Remote Access** | Tailscale (private) or Cloudflare Tunnel (public domain) — no open ports |
| **Production Hardened** | Memory limits, security headers, log rotation, swap management, fail2ban |

## Access Methods

The installer asks how you want to access Paperless. Choose based on your needs:

| Method | Security | Setup | Best For |
|--------|----------|-------|----------|
| **Tailscale** (recommended) | Private network, encrypted | Install Tailscale on your devices | Personal use, maximum security |
| **Cloudflare Tunnel** | Behind Cloudflare, your domain | Requires a domain + CF account | Sharing with family/team |
| **Both** | Best of both worlds | Tailscale + CF Tunnel | Flexibility |
| **Local only** | Localhost only | Nothing extra | Testing, single machine |
| **Direct expose** | Open to internet | Not recommended | You know what you're doing |

## Configuration

All settings live in a single `.env` file at your install directory. Edit and restart:

```bash
nano ~/paperless/.env
cd ~/paperless && docker compose up -d
```

### Key Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `PAPERLESS_ADMIN_USER` | Admin username | `admin` |
| `PAPERLESS_ADMIN_PASSWORD` | Admin password | Set during install |
| `PAPERLESS_TIMEZONE` | Timezone | Auto-detected |
| `PAPERLESS_OCR_LANGUAGE` | OCR languages | `eng` |
| `LLM_PROVIDER` | AI provider (`googleai`, `openai`, `ollama`, `none`) | Set during install |
| `LLM_MODEL` | Model name | Provider default |
| `ACCESS_METHOD` | How to access (`tailscale`, `cloudflare`, `both`, `local`) | Set during install |
| `ENABLE_BACKUPS` | Automated backups | `false` |

## Backup & Restore

### Automated Backups

If enabled during install, backups run daily at 3:00 AM:

- **Daily** backups: kept 7 days
- **Weekly** backups (Sundays): kept 28 days
- **Monthly** backups (1st): kept 90 days

Destinations: Google Drive, Dropbox, OneDrive, or any rclone remote. Optionally encrypted to a GitHub repo.

### Manual Backup

```bash
cd ~/paperless
./backup.sh
```

### Restore

```bash
cd ~/paperless
./restore.sh
```

Interactive menu to restore from cloud, encrypted file, or local backup.

### Test a Backup

```bash
./restore-test.sh /path/to/backup.zip
```

Non-destructive integrity check.

## Document Workflows

### Import Methods

1. **Web UI** — drag and drop in the browser
2. **Consume folder** — drop files in `~/paperless/consume/`
3. **Email** — configure SMTP and Paperless fetches attachments automatically
4. **Google Drive** — rclone syncs a GDrive folder to the consume directory
5. **Mobile** — use the official Paperless-NGX mobile app

### AI Classification

When AI is enabled, tagged documents are automatically processed:

1. Document arrives in Paperless
2. paperless-gpt picks it up (via `paperless-gpt-auto` tag)
3. LLM analyzes the document content
4. Automatically assigns: title, correspondent, document type, tags, date

### ASN Barcode System

For physical filing with printed labels:

1. Print ASN labels (QR codes with `ASN00001`, `ASN00002`, etc.)
2. Stick label on physical document
3. Scan the document — Paperless reads the barcode automatically
4. If the barcode scanner misses it, the fallback script tries corner-crop + upscale
5. Last resort: OCR text extraction looks for `ASN` pattern

## Services

| Container | Port | Memory | Role |
|-----------|------|--------|------|
| paperless-ngx | 8000 | 3 GB | Core document management |
| paperless-gpt | 8080 | 256 MB | AI classification (optional) |
| postgres | 5432 | 512 MB | Database |
| redis | 6379 | 256 MB | Cache and task queue |
| gotenberg | 3000 | 512 MB | Document conversion |
| tika | 9998 | 512 MB | Text extraction |
| cloudflared | — | 128 MB | Cloudflare Tunnel (optional) |

**Minimum requirements:** 4 GB RAM (8 GB recommended), 2 CPU cores, 20 GB disk

## Management

```bash
cd ~/paperless

# View logs
docker compose logs paperless --tail 50

# Restart
docker compose restart paperless

# Update all containers
docker compose pull && docker compose up -d

# Stop everything
docker compose down

# Check health
docker compose ps
docker compose exec paperless document_sanity_checker
```

## Troubleshooting

### Regenerate API token

```bash
docker compose exec paperless python3 manage.py shell -c "
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token
User = get_user_model()
admin = User.objects.get(username='admin')
token, _ = Token.objects.get_or_create(user=admin)
print(f'Token: {token.key}')
"
```

### Reset admin password

```bash
docker compose exec paperless python3 manage.py changepassword admin
```

### Check disk usage

```bash
du -sh ~/paperless/media/
df -h /
```

## Acknowledgments

This project is built on top of amazing open-source software. Huge thanks to:

- [**Paperless-NGX**](https://github.com/paperless-ngx/paperless-ngx) — The core document management system that makes this all possible
- [**paperless-gpt**](https://github.com/icereed/paperless-gpt) by [@icereed](https://github.com/icereed) — AI-powered document classification and OCR integration
- [**Gotenberg**](https://github.com/gotenberg/gotenberg) — Document conversion API
- [**Apache Tika**](https://github.com/apache/tika) — Content analysis and text extraction
- [**PostgreSQL**](https://www.postgresql.org/) — The database engine
- [**Redis**](https://github.com/redis/redis) — Cache and task queue
- [**Cloudflare Tunnel**](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) — Secure tunneling without open ports
- [**Tailscale**](https://tailscale.com/) — Private mesh networking
- [**Ollama**](https://github.com/ollama/ollama) — Local LLM inference
- [**rclone**](https://github.com/rclone/rclone) — Cloud storage sync for backups
- [**Docker**](https://www.docker.com/) — Containerization

## Uninstall

To remove Paperless Overconfigured:

```bash
cd ~/paperless
./uninstall.sh
```

Interactive menu with three levels:
1. **Stop only** — stop containers, keep all data
2. **Stop + remove volumes** — removes database and Redis data
3. **Full removal** — removes everything including documents, config, and cron jobs

---

> [!CAUTION]
> ## Disclaimer
>
> This project is **not affiliated with, endorsed by, or sponsored by** any of the projects listed above, including Paperless-NGX, Cloudflare, Tailscale, Google, OpenAI, or any other mentioned service or software.
>
> This repository is created and maintained as a **personal hobby project**. It is provided as-is, with **no warranties or guarantees of any kind**.
>
> **You are solely responsible for:**
> - Your data, documents, and backups
> - The security of your installation and credentials
> - Any data loss, leakage, or corruption that may occur
> - Compliance with applicable laws and regulations (including GDPR, data residency, etc.)
> - Reviewing and understanding the configuration before deploying to production
>
> **Always keep independent backups of your important documents. Test your backup and restore procedures regularly.**

## License

MIT
