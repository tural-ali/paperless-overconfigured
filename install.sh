#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Paperless Overconfigured — One-Command Installer           ║
# ║                                                              ║
# ║  Usage:                                                      ║
# ║    bash <(curl -fsSL https://raw.githubusercontent.com/      ║
# ║      USER/paperless-overconfigured/main/install.sh)          ║
# ║                                                              ║
# ║  Works on: Ubuntu/Debian, Fedora/RHEL, macOS, NixOS         ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail
# shellcheck source=/dev/null

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
fatal()   { echo -e "${RED}[FATAL]${NC} $1"; exit 1; }
step()    { echo -e "\n${CYAN}${BOLD}$1${NC}"; }
prompt()  { echo -ne "${BOLD}$1${NC}"; }

ask() {
    local var="$1" message="$2" default="$3"
    if [ -n "$default" ]; then
        prompt "$message [$default]: "
        read -r input
        eval "$var=\"${input:-$default}\""
    else
        prompt "$message: "
        read -r input
        eval "$var=\"$input\""
    fi
}

ask_secret() {
    local var="$1" message="$2"
    prompt "$message: "
    read -rs input
    echo
    eval "$var=\"$input\""
}

ask_choice() {
    local var="$1" message="$2"
    shift 2
    local options=("$@")
    echo -e "\n${BOLD}$message${NC}"
    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${options[$i]}"
    done
    prompt "Enter choice [1-${#options[@]}]: "
    read -r choice
    eval "$var=\"$choice\""
}

generate_secret() {
    openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

generate_password() {
    openssl rand -base64 16 2>/dev/null | tr -d '=/+' | head -c 16
}

# ── OS Detection ──────────────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|pop|linuxmint) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            nixos) echo "nixos" ;;
            *) echo "linux-unknown" ;;
        esac
    elif [ "$(uname)" = "Darwin" ]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) uname -m ;;
    esac
}

# ══════════════════════════════════════════════════════════════
# PHASE 1: WELCOME
# ══════════════════════════════════════════════════════════════

clear 2>/dev/null || true
echo -e "${CYAN}"
cat << 'BANNER'

  ██████╗  █████╗ ██████╗ ███████╗██████╗ ██╗     ███████╗███████╗███████╗
  ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗██║     ██╔════╝██╔════╝██╔════╝
  ██████╔╝███████║██████╔╝█████╗  ██████╔╝██║     █████╗  ███████╗███████╗
  ██╔═══╝ ██╔══██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══╝  ╚════██║╚════██║
  ██║     ██║  ██║██║     ███████╗██║  ██║███████╗███████╗███████║███████║
  ╚═╝     ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝
                         OVERCONFIGURED

BANNER
echo -e "${NC}"
echo -e "${DIM}  A production-ready, AI-powered document management stack.${NC}"
echo -e "${DIM}  Paperless-NGX + AI classification + automated backups.${NC}"
echo ""
echo -e "${DIM}  OS: $(uname -s) $(uname -m) | Shell: $SHELL${NC}"
echo ""

OS=$(detect_os)
ARCH=$(detect_arch)

if [ "$OS" = "unknown" ]; then
    fatal "Unsupported operating system. Supported: Ubuntu/Debian, Fedora/RHEL, macOS, NixOS"
fi

success "Detected: $OS ($ARCH)"
echo ""
echo -e "${YELLOW}This installer will:${NC}"
echo "  1. Install dependencies (Docker, etc.)"
echo "  2. Ask you a few questions to configure the stack"
echo "  3. Generate all config files"
echo "  4. Start the Paperless-NGX stack"
echo "  5. Optionally set up backups and remote access"
echo ""
prompt "Press Enter to continue (or Ctrl+C to abort)..."
read -r

# ══════════════════════════════════════════════════════════════
# PHASE 2: INTERACTIVE WIZARD
# ══════════════════════════════════════════════════════════════

step "[1/8] Installation Directory"
echo -e "${DIM}Where should Paperless be installed?${NC}"
if [ "$OS" = "macos" ]; then
    DEFAULT_DIR="$HOME/paperless"
else
    DEFAULT_DIR="$HOME/paperless"
fi
ask INSTALL_DIR "Directory" "$DEFAULT_DIR"
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
    warn "Existing installation detected at $INSTALL_DIR"
    prompt "Overwrite configuration? (y/N): "
    read -r overwrite
    if [[ ! "$overwrite" =~ ^[Yy] ]]; then
        fatal "Aborted. Remove or rename $INSTALL_DIR first."
    fi
fi

# ──────────────────────────────────────────────────────────────
step "[2/8] Admin Credentials"
echo -e "${DIM}Create your Paperless admin account.${NC}"
ask ADMIN_USER "Username" "admin"
while true; do
    ask_secret ADMIN_PASS "Password"
    if [ ${#ADMIN_PASS} -lt 8 ]; then
        warn "Password must be at least 8 characters."
    else
        break
    fi
done

# ──────────────────────────────────────────────────────────────
step "[3/8] Remote Access"
echo -e "${DIM}How will you access Paperless from outside this machine?${NC}"
echo ""
echo -e "  ${CYAN}1)${NC} ${GREEN}Tailscale (recommended)${NC}"
echo -e "     ${DIM}Private network. Only your devices can access it.${NC}"
echo -e "     ${DIM}Free for personal use. No ports exposed to the internet.${NC}"
echo ""
echo -e "  ${CYAN}2)${NC} Cloudflare Tunnel"
echo -e "     ${DIM}Access via your own domain through Cloudflare.${NC}"
echo -e "     ${DIM}Protected by Cloudflare Access. Requires a domain.${NC}"
echo ""
echo -e "  ${CYAN}3)${NC} Both Tailscale + Cloudflare Tunnel"
echo ""
echo -e "  ${CYAN}4)${NC} Local only (localhost)"
echo -e "     ${DIM}Only accessible from this machine.${NC}"
echo ""
echo -e "  ${CYAN}5)${NC} ${RED}Expose to internet directly (NOT recommended)${NC}"
echo -e "     ${RED}     Your documents will be accessible to anyone who finds the IP.${NC}"
echo -e "     ${RED}     Only use this if you know what you are doing.${NC}"
echo ""
prompt "Enter choice [1-5]: "
read -r ACCESS_CHOICE

TAILSCALE_HOSTNAME=""
PAPERLESS_DOMAIN=""
CLOUDFLARE_TUNNEL_TOKEN=""
COMPOSE_PROFILES=""

case "$ACCESS_CHOICE" in
    1)
        ACCESS_METHOD="tailscale"
        info "Checking Tailscale..."
        if command -v tailscale &>/dev/null; then
            TS_STATUS=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Self',{}).get('DNSName','').rstrip('.'))" 2>/dev/null || true)
            if [ -n "$TS_STATUS" ]; then
                success "Tailscale detected: $TS_STATUS"
                TAILSCALE_HOSTNAME="$TS_STATUS"
            fi
        fi
        if [ -z "$TAILSCALE_HOSTNAME" ]; then
            warn "Tailscale not detected. Install it after setup: https://tailscale.com/download"
            ask TAILSCALE_HOSTNAME "Tailscale hostname (or press Enter to set later)" ""
        fi
        ;;
    2)
        ACCESS_METHOD="cloudflare"
        COMPOSE_PROFILES="tunnel"
        ask PAPERLESS_DOMAIN "Your domain for Paperless (e.g. docs.example.com)" ""
        echo -e "${DIM}Get your tunnel token from: Cloudflare Zero Trust > Networks > Tunnels${NC}"
        ask CLOUDFLARE_TUNNEL_TOKEN "Cloudflare Tunnel token" ""
        ;;
    3)
        ACCESS_METHOD="both"
        COMPOSE_PROFILES="tunnel"
        if command -v tailscale &>/dev/null; then
            TS_STATUS=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Self',{}).get('DNSName','').rstrip('.'))" 2>/dev/null || true)
            if [ -n "$TS_STATUS" ]; then
                TAILSCALE_HOSTNAME="$TS_STATUS"
                success "Tailscale detected: $TS_STATUS"
            fi
        fi
        [ -z "$TAILSCALE_HOSTNAME" ] && ask TAILSCALE_HOSTNAME "Tailscale hostname" ""
        ask PAPERLESS_DOMAIN "Your domain for Paperless (e.g. docs.example.com)" ""
        ask CLOUDFLARE_TUNNEL_TOKEN "Cloudflare Tunnel token" ""
        ;;
    4)
        ACCESS_METHOD="local"
        ;;
    5)
        ACCESS_METHOD="exposed"
        echo ""
        echo -e "${RED}${BOLD}  WARNING: This will expose Paperless directly to the internet.${NC}"
        echo -e "${RED}  Your personal documents will be accessible to anyone who finds your IP.${NC}"
        echo -e "${RED}  You should at minimum set a very strong password and use HTTPS.${NC}"
        echo ""
        prompt "Type 'I understand the risks' to continue: "
        read -r confirm
        if [ "$confirm" != "I understand the risks" ]; then
            fatal "Aborted. Choose a safer access method."
        fi
        ;;
    *)
        fatal "Invalid choice"
        ;;
esac

# ──────────────────────────────────────────────────────────────
step "[4/8] AI-Powered Document Classification"
echo -e "${DIM}paperless-gpt automatically classifies, tags, and titles your documents.${NC}"
echo -e "${DIM}It requires an LLM provider. You can skip this and add it later.${NC}"
echo ""
echo -e "  ${CYAN}1)${NC} ${GREEN}Google AI (Gemini) — recommended${NC}"
echo -e "     ${DIM}Fast, cheap (~\$0.001/document). Get key: https://aistudio.google.com${NC}"
echo ""
echo -e "  ${CYAN}2)${NC} OpenAI (GPT-4o)"
echo -e "     ${DIM}High quality. Get key: https://platform.openai.com/api-keys${NC}"
echo ""
echo -e "  ${CYAN}3)${NC} Ollama (local LLM)"
echo -e "     ${DIM}Fully private. Requires Ollama running locally or on your network.${NC}"
echo ""
echo -e "  ${CYAN}4)${NC} Skip — no AI classification"
echo ""
prompt "Enter choice [1-4]: "
read -r AI_CHOICE

LLM_PROVIDER="none"
LLM_MODEL=""
GOOGLEAI_API_KEY=""
OPENAI_API_KEY=""
OLLAMA_HOST=""
OCR_PROVIDER="llm"
GOOGLE_PROJECT_ID=""
GOOGLE_LOCATION=""
GOOGLE_PROCESSOR_ID=""

case "$AI_CHOICE" in
    1)
        LLM_PROVIDER="googleai"
        LLM_MODEL="gemini-2.5-flash"
        if [ -n "$COMPOSE_PROFILES" ]; then
            COMPOSE_PROFILES="${COMPOSE_PROFILES},ai"
        else
            COMPOSE_PROFILES="ai"
        fi
        ask GOOGLEAI_API_KEY "Google AI API key" ""
        ask LLM_MODEL "Model name" "gemini-2.5-flash"
        echo ""
        echo -e "${DIM}Optional: Google Document AI for high-quality OCR (requires GCP project)${NC}"
        prompt "Set up Document AI OCR? (y/N): "
        read -r docai
        if [[ "$docai" =~ ^[Yy] ]]; then
            OCR_PROVIDER="google_docai"
            ask GOOGLE_PROJECT_ID "GCP Project ID" ""
            ask GOOGLE_LOCATION "Location" "eu"
            ask GOOGLE_PROCESSOR_ID "Processor ID" ""
            echo -e "${DIM}Place your service account JSON at: $INSTALL_DIR/google-ai.json${NC}"
        fi
        ;;
    2)
        LLM_PROVIDER="openai"
        LLM_MODEL="gpt-4o"
        if [ -n "$COMPOSE_PROFILES" ]; then
            COMPOSE_PROFILES="${COMPOSE_PROFILES},ai"
        else
            COMPOSE_PROFILES="ai"
        fi
        ask OPENAI_API_KEY "OpenAI API key" ""
        ask LLM_MODEL "Model name" "gpt-4o"
        ;;
    3)
        LLM_PROVIDER="ollama"
        LLM_MODEL="llama3"
        if [ -n "$COMPOSE_PROFILES" ]; then
            COMPOSE_PROFILES="${COMPOSE_PROFILES},ai"
        else
            COMPOSE_PROFILES="ai"
        fi
        ask OLLAMA_HOST "Ollama URL" "http://host.docker.internal:11434"
        ask LLM_MODEL "Model name" "llama3"
        ;;
    4)
        info "Skipping AI classification. You can enable it later in .env"
        ;;
    *)
        info "Skipping AI."
        ;;
esac

# ──────────────────────────────────────────────────────────────
step "[5/8] OCR Languages"
echo -e "${DIM}Which languages are your documents in?${NC}"
echo ""
echo -e "  ${CYAN}1)${NC} English only"
echo -e "  ${CYAN}2)${NC} German + English"
echo -e "  ${CYAN}3)${NC} French + English"
echo -e "  ${CYAN}4)${NC} Spanish + English"
echo -e "  ${CYAN}5)${NC} Custom (enter Tesseract language codes)"
echo ""
prompt "Enter choice [1-5]: "
read -r OCR_CHOICE

OCR_LANGUAGE="eng"
OCR_EXTRA_LANGUAGES=""

case "$OCR_CHOICE" in
    1) OCR_LANGUAGE="eng" ;;
    2) OCR_LANGUAGE="deu+eng" ;;
    3) OCR_LANGUAGE="fra+eng" ;;
    4) OCR_LANGUAGE="spa+eng" ;;
    5)
        ask OCR_LANGUAGE "Primary OCR languages (e.g. deu+eng)" "eng"
        ask OCR_EXTRA_LANGUAGES "Additional languages to install (e.g. tur aze)" ""
        ;;
    *) OCR_LANGUAGE="eng" ;;
esac

# ──────────────────────────────────────────────────────────────
step "[6/8] Automated Backups"
echo -e "${DIM}Paperless can automatically back up your documents on a schedule.${NC}"
echo ""
echo -e "  ${CYAN}1)${NC} ${GREEN}Google Drive (recommended)${NC}"
echo -e "     ${DIM}Daily/weekly/monthly rotation via rclone.${NC}"
echo ""
echo -e "  ${CYAN}2)${NC} Google Drive + encrypted GitHub backup"
echo -e "     ${DIM}Encrypted (AES-256) copies pushed to a private GitHub repo.${NC}"
echo ""
echo -e "  ${CYAN}3)${NC} Dropbox"
echo -e "     ${DIM}Daily/weekly/monthly rotation via rclone.${NC}"
echo ""
echo -e "  ${CYAN}4)${NC} OneDrive"
echo -e "     ${DIM}Daily/weekly/monthly rotation via rclone.${NC}"
echo ""
echo -e "  ${CYAN}5)${NC} Custom rclone remote"
echo -e "     ${DIM}Any rclone-supported backend (S3, B2, SFTP, etc.)${NC}"
echo ""
echo -e "  ${CYAN}6)${NC} Local only (no cloud backup)"
echo ""
echo -e "  ${CYAN}7)${NC} Skip backups for now"
echo ""
prompt "Enter choice [1-7]: "
read -r BACKUP_CHOICE

ENABLE_BACKUPS="false"
ENCRYPTION_PASSPHRASE=""
HEALTHCHECK_URL=""
RCLONE_REMOTE=""
RCLONE_BACKUP_DIR="Backups/Paperless"
GITHUB_BACKUP_REPO=""
RCLONE_PROVIDER=""

case "$BACKUP_CHOICE" in
    1)
        ENABLE_BACKUPS="true"
        RCLONE_REMOTE="Gdrive"
        RCLONE_PROVIDER="drive"
        ;;
    2)
        ENABLE_BACKUPS="true"
        RCLONE_REMOTE="Gdrive"
        RCLONE_PROVIDER="drive"
        ask GITHUB_BACKUP_REPO "GitHub repo for encrypted backup (e.g. user/paperless-backup)" ""
        ask_secret ENCRYPTION_PASSPHRASE "Encryption passphrase for backups"
        ;;
    3)
        ENABLE_BACKUPS="true"
        RCLONE_REMOTE="Dropbox"
        RCLONE_PROVIDER="dropbox"
        ;;
    4)
        ENABLE_BACKUPS="true"
        RCLONE_REMOTE="OneDrive"
        RCLONE_PROVIDER="onedrive"
        ;;
    5)
        ENABLE_BACKUPS="true"
        ask RCLONE_REMOTE "rclone remote name" "MyRemote"
        RCLONE_PROVIDER="custom"
        ;;
    6)
        ENABLE_BACKUPS="true"
        RCLONE_REMOTE=""
        RCLONE_PROVIDER="local"
        ;;
    7)
        info "Skipping backups. You can set them up later."
        ;;
esac

if [ "$ENABLE_BACKUPS" = "true" ]; then
    echo ""
    echo -e "${DIM}Optional: Healthchecks.io monitoring (get a free ping URL at healthchecks.io)${NC}"
    ask HEALTHCHECK_URL "Healthchecks.io URL (or Enter to skip)" ""
fi

# ──────────────────────────────────────────────────────────────
step "[7/8] Email Integration"
echo -e "${DIM}Paperless can automatically import documents from email attachments.${NC}"
prompt "Set up email ingestion? (y/N): "
read -r EMAIL_SETUP

EMAIL_HOST=""
EMAIL_PORT="465"
EMAIL_USER=""
EMAIL_PASSWORD=""
EMAIL_USE_SSL="true"
EMAIL_FROM=""

if [[ "$EMAIL_SETUP" =~ ^[Yy] ]]; then
    ask EMAIL_HOST "SMTP host (e.g. smtp.gmail.com)" ""
    ask EMAIL_PORT "SMTP port" "465"
    ask EMAIL_USER "Email username" ""
    ask_secret EMAIL_PASSWORD "Email password / app password"
    ask EMAIL_FROM "From address" "$EMAIL_USER"
    EMAIL_USE_SSL="true"
fi

# ──────────────────────────────────────────────────────────────
step "[8/8] Timezone"
DETECTED_TZ=$(cat /etc/timezone 2>/dev/null || readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "UTC")
ask TIMEZONE "Timezone" "$DETECTED_TZ"

# ══════════════════════════════════════════════════════════════
# PHASE 3: INSTALL DEPENDENCIES
# ══════════════════════════════════════════════════════════════

step "Installing dependencies..."

install_docker() {
    if command -v docker &>/dev/null; then
        success "Docker already installed: $(docker --version 2>/dev/null | head -1)"
        return 0
    fi
    case "$OS" in
        debian)
            info "Installing Docker..."
            curl -fsSL https://get.docker.com | sudo sh
            sudo usermod -aG docker "$USER"
            success "Docker installed. You may need to log out and back in."
            ;;
        fedora)
            info "Installing Docker..."
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo systemctl enable --now docker
            sudo usermod -aG docker "$USER"
            success "Docker installed."
            ;;
        macos)
            if ! command -v docker &>/dev/null; then
                echo ""
                echo -e "${YELLOW}Docker Desktop is required on macOS.${NC}"
                echo -e "Download it from: ${CYAN}https://www.docker.com/products/docker-desktop/${NC}"
                echo ""
                prompt "Press Enter after installing Docker Desktop..."
                read -r
                if ! command -v docker &>/dev/null; then
                    fatal "Docker not found. Please install Docker Desktop first."
                fi
            fi
            ;;
        nixos)
            warn "On NixOS, add docker to your configuration.nix and rebuild."
            warn "  virtualisation.docker.enable = true;"
            warn "  users.users.$USER.extraGroups = [ \"docker\" ];"
            if ! command -v docker &>/dev/null; then
                fatal "Docker not found. Configure it in your NixOS config and rebuild."
            fi
            ;;
    esac
}

install_packages() {
    case "$OS" in
        debian)
            info "Installing system packages..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq curl git unzip fail2ban qpdf poppler-utils imagemagick >/dev/null 2>&1
            success "System packages installed"
            ;;
        fedora)
            info "Installing system packages..."
            sudo dnf install -y -q curl git unzip fail2ban qpdf poppler-utils ImageMagick >/dev/null 2>&1
            success "System packages installed"
            ;;
        macos)
            if command -v brew &>/dev/null; then
                info "Installing packages via Homebrew..."
                brew install --quiet qpdf poppler imagemagick 2>/dev/null
                success "Packages installed"
            else
                warn "Homebrew not found. Install it from https://brew.sh"
                warn "Then run: brew install qpdf poppler imagemagick"
            fi
            ;;
        nixos)
            info "On NixOS, add these to your environment.systemPackages:"
            echo "  qpdf poppler_utils imagemagick"
            ;;
    esac
}

install_rclone() {
    if [ "$ENABLE_BACKUPS" != "true" ] || [ -z "$RCLONE_REMOTE" ] || [ "$RCLONE_PROVIDER" = "local" ]; then
        return 0
    fi
    if command -v rclone &>/dev/null; then
        success "rclone already installed: $(rclone version 2>/dev/null | head -1)"
        return 0
    fi
    case "$OS" in
        debian|fedora|linux-unknown)
            info "Installing rclone..."
            curl -fsSL https://rclone.org/install.sh | sudo bash
            success "rclone installed"
            ;;
        macos)
            if command -v brew &>/dev/null; then
                brew install --quiet rclone 2>/dev/null
                success "rclone installed"
            else
                curl -fsSL https://rclone.org/install.sh | sudo bash
                success "rclone installed"
            fi
            ;;
        nixos)
            warn "Add rclone to your NixOS config or run: nix-env -iA nixpkgs.rclone"
            ;;
    esac
}

install_docker
install_packages
install_rclone

# ══════════════════════════════════════════════════════════════
# PHASE 4: SYSTEM CONFIGURATION (Linux only)
# ══════════════════════════════════════════════════════════════

if [ "$OS" != "macos" ]; then
    step "Configuring system..."

    # Firewall
    if command -v ufw &>/dev/null; then
        info "Configuring firewall (UFW)..."
        sudo ufw allow OpenSSH >/dev/null 2>&1
        if [ "$ACCESS_METHOD" = "exposed" ]; then
            sudo ufw allow 8000/tcp >/dev/null 2>&1
            warn "Port 8000 opened to the internet"
        fi
        sudo ufw --force enable >/dev/null 2>&1
        success "Firewall configured"
    fi

    # Swap
    TOTAL_MEM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
    if [ "$TOTAL_MEM_MB" -gt 0 ] && [ "$TOTAL_MEM_MB" -lt 8192 ]; then
        if ! swapon --show 2>/dev/null | grep -q '/swapfile'; then
            info "Creating 4 GB swap (detected ${TOTAL_MEM_MB}MB RAM)..."
            sudo fallocate -l 4G /swapfile
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile >/dev/null
            sudo swapon /swapfile
            grep -q '/swapfile' /etc/fstab || echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
            echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
            sudo sysctl vm.swappiness=10 >/dev/null 2>&1
            success "4 GB swap created"
        fi
    fi

    # Docker log rotation
    if [ ! -f /etc/docker/daemon.json ] || ! grep -q "max-size" /etc/docker/daemon.json 2>/dev/null; then
        info "Configuring Docker log rotation..."
        sudo mkdir -p /etc/docker
        echo '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}' | sudo tee /etc/docker/daemon.json >/dev/null
        sudo systemctl restart docker 2>/dev/null || true
        success "Docker log rotation configured"
    fi

    # journald cap
    if [ ! -f /etc/systemd/journald.conf.d/size.conf ]; then
        sudo mkdir -p /etc/systemd/journald.conf.d
        printf '[Journal]\nSystemMaxUse=50M\nSystemMaxFileSize=10M\n' | sudo tee /etc/systemd/journald.conf.d/size.conf >/dev/null
        sudo systemctl restart systemd-journald >/dev/null 2>&1 || true
    fi
fi

# ══════════════════════════════════════════════════════════════
# PHASE 5: CREATE DIRECTORY STRUCTURE & CONFIG FILES
# ══════════════════════════════════════════════════════════════

step "Creating installation at $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR"/{data,media,export,consume,redis,db,prompts,scripts,backups}

# ── Generate secrets ──────────────────────────────────────────
SECRET_KEY=$(generate_secret)
DB_PASSWORD=$(generate_password)

# ── Build URL and allowed hosts ───────────────────────────────
PAPERLESS_URL="http://localhost:8000"
ALLOWED_HOSTS="localhost,paperless:8000,paperless,paperless-ngx"
CORS_HOSTS=""
CSRF_ORIGINS=""

case "$ACCESS_METHOD" in
    tailscale)
        if [ -n "$TAILSCALE_HOSTNAME" ]; then
            PAPERLESS_URL="https://$TAILSCALE_HOSTNAME"
            ALLOWED_HOSTS="$ALLOWED_HOSTS,$TAILSCALE_HOSTNAME"
            CORS_HOSTS="https://$TAILSCALE_HOSTNAME"
            CSRF_ORIGINS="https://$TAILSCALE_HOSTNAME"
        fi
        ;;
    cloudflare)
        if [ -n "$PAPERLESS_DOMAIN" ]; then
            PAPERLESS_URL="https://$PAPERLESS_DOMAIN"
            ALLOWED_HOSTS="$ALLOWED_HOSTS,$PAPERLESS_DOMAIN"
            CORS_HOSTS="https://$PAPERLESS_DOMAIN"
            CSRF_ORIGINS="https://$PAPERLESS_DOMAIN"
        fi
        ;;
    both)
        URLS=""
        if [ -n "$TAILSCALE_HOSTNAME" ]; then
            PAPERLESS_URL="https://$TAILSCALE_HOSTNAME"
            ALLOWED_HOSTS="$ALLOWED_HOSTS,$TAILSCALE_HOSTNAME"
            URLS="https://$TAILSCALE_HOSTNAME"
        fi
        if [ -n "$PAPERLESS_DOMAIN" ]; then
            [ -z "$PAPERLESS_URL" ] || [ "$PAPERLESS_URL" = "http://localhost:8000" ] && PAPERLESS_URL="https://$PAPERLESS_DOMAIN"
            ALLOWED_HOSTS="$ALLOWED_HOSTS,$PAPERLESS_DOMAIN"
            [ -n "$URLS" ] && URLS="$URLS,https://$PAPERLESS_DOMAIN" || URLS="https://$PAPERLESS_DOMAIN"
        fi
        CORS_HOSTS="$URLS"
        CSRF_ORIGINS="$URLS"
        ;;
    exposed)
        SERVER_IP=$(curl -s4 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
        PAPERLESS_URL="http://$SERVER_IP:8000"
        ALLOWED_HOSTS="*"
        ;;
esac

# ── Write .env ────────────────────────────────────────────────
info "Writing configuration..."
cat > "$INSTALL_DIR/.env" << ENVEOF
# Paperless Overconfigured — Configuration
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Core ──
INSTALL_DIR=$INSTALL_DIR
PAPERLESS_ADMIN_USER=$ADMIN_USER
PAPERLESS_ADMIN_PASSWORD=$ADMIN_PASS
PAPERLESS_SECRET_KEY=$SECRET_KEY
PAPERLESS_TIMEZONE=$TIMEZONE

# ── Access ──
ACCESS_METHOD=$ACCESS_METHOD
PAPERLESS_URL=$PAPERLESS_URL
PAPERLESS_ALLOWED_HOSTS=$ALLOWED_HOSTS
PAPERLESS_CORS_ALLOWED_HOSTS=$CORS_HOSTS
PAPERLESS_CSRF_TRUSTED_ORIGINS=$CSRF_ORIGINS
TAILSCALE_HOSTNAME=$TAILSCALE_HOSTNAME
PAPERLESS_DOMAIN=$PAPERLESS_DOMAIN
CLOUDFLARE_TUNNEL_TOKEN=$CLOUDFLARE_TUNNEL_TOKEN

# ── OCR ──
PAPERLESS_OCR_LANGUAGE=$OCR_LANGUAGE
PAPERLESS_OCR_LANGUAGES=$OCR_EXTRA_LANGUAGES

# ── AI / LLM ──
LLM_PROVIDER=$LLM_PROVIDER
LLM_MODEL=$LLM_MODEL
GOOGLEAI_API_KEY=$GOOGLEAI_API_KEY
OPENAI_API_KEY=$OPENAI_API_KEY
OLLAMA_HOST=$OLLAMA_HOST
OCR_PROVIDER=$OCR_PROVIDER
GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID
GOOGLE_LOCATION=$GOOGLE_LOCATION
GOOGLE_PROCESSOR_ID=$GOOGLE_PROCESSOR_ID

# ── Database ──
POSTGRES_DB=paperless
POSTGRES_USER=paperless
POSTGRES_PASSWORD=$DB_PASSWORD

# ── Email ──
PAPERLESS_EMAIL_HOST=$EMAIL_HOST
PAPERLESS_EMAIL_PORT=$EMAIL_PORT
PAPERLESS_EMAIL_HOST_USER=$EMAIL_USER
PAPERLESS_EMAIL_HOST_PASSWORD=$EMAIL_PASSWORD
PAPERLESS_EMAIL_USE_SSL=$EMAIL_USE_SSL
PAPERLESS_EMAIL_FROM=$EMAIL_FROM

# ── Backups ──
ENABLE_BACKUPS=$ENABLE_BACKUPS
ENCRYPTION_PASSPHRASE=$ENCRYPTION_PASSPHRASE
HEALTHCHECK_URL=$HEALTHCHECK_URL
RCLONE_REMOTE=$RCLONE_REMOTE
RCLONE_BACKUP_DIR=$RCLONE_BACKUP_DIR
GITHUB_BACKUP_REPO=$GITHUB_BACKUP_REPO

# ── Docker Compose ──
COMPOSE_PROFILES=$COMPOSE_PROFILES

# ── API Token (generated after first start) ──
PAPERLESS_API_TOKEN=
ENVEOF

chmod 600 "$INSTALL_DIR/.env"
success "Configuration written to $INSTALL_DIR/.env"

# ── Determine repo source (local clone or curl download) ─────
REPO_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/templates/docker-compose.yml" ]; then
    REPO_DIR="$SCRIPT_DIR"
else
    info "Downloading configuration files..."
    REPO_DIR=$(mktemp -d)
    trap 'rm -rf "$REPO_DIR"' EXIT
    if command -v git &>/dev/null; then
        git clone --depth 1 https://github.com/tural-ali/paperless-overconfigured.git "$REPO_DIR" 2>/dev/null
    else
        curl -fsSL https://github.com/tural-ali/paperless-overconfigured/archive/main.tar.gz | tar xz -C "$REPO_DIR" --strip-components=1
    fi
    success "Files downloaded"
fi

# ── Copy docker-compose.yml ───────────────────────────────────
cp "$REPO_DIR/templates/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml"

# ── Adjust port binding if exposed ────────────────────────────
if [ "$ACCESS_METHOD" = "exposed" ]; then
    sed -i.bak 's|127.0.0.1:8000:8000|0.0.0.0:8000:8000|g' "$INSTALL_DIR/docker-compose.yml"
    rm -f "$INSTALL_DIR/docker-compose.yml.bak"
    warn "Paperless port bound to 0.0.0.0:8000 (publicly accessible)"
fi

# ── Copy prompts ──────────────────────────────────────────────
if [ -d "$REPO_DIR/prompts" ]; then
    cp "$REPO_DIR/prompts/"*.tmpl "$INSTALL_DIR/prompts/" 2>/dev/null || true
fi

# ── Copy scripts ──────────────────────────────────────────────
if [ -d "$REPO_DIR/scripts" ]; then
    cp "$REPO_DIR/scripts/"* "$INSTALL_DIR/scripts/" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true
fi

# ── Create google-ai.json placeholder if AI enabled ──────────
if [ "$LLM_PROVIDER" != "none" ] && [ ! -f "$INSTALL_DIR/google-ai.json" ]; then
    echo '{}' > "$INSTALL_DIR/google-ai.json"
fi

success "All files deployed to $INSTALL_DIR"

# ══════════════════════════════════════════════════════════════
# PHASE 6: GENERATE BACKUP & RESTORE SCRIPTS
# ══════════════════════════════════════════════════════════════

step "Creating backup and restore scripts..."

# ── backup.sh ─────────────────────────────────────────────────
cat > "$INSTALL_DIR/backup.sh" << 'BACKUPEOF'
#!/bin/bash
# Paperless Overconfigured — Automated Backup Script
# Schedule: add to crontab — 0 3 * * * /path/to/backup.sh >> /path/to/backup.log 2>&1

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env" 2>/dev/null || true

DATE=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%u)
DAY_OF_MONTH=$(date +%d)
BACKUP_DIR="$INSTALL_DIR/backups"
LOG="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Healthchecks.io
hc_start() { [ -n "$HEALTHCHECK_URL" ] && curl -fsS -m 10 --retry 5 "${HEALTHCHECK_URL}/start" >/dev/null 2>&1 || true; }
hc_ok()    { [ -n "$HEALTHCHECK_URL" ] && curl -fsS -m 10 --retry 5 "$HEALTHCHECK_URL" >/dev/null 2>&1 || true; }
hc_fail()  { [ -n "$HEALTHCHECK_URL" ] && curl -fsS -m 10 --retry 5 "${HEALTHCHECK_URL}/fail" >/dev/null 2>&1 || true; }

hc_start
trap 'hc_fail' ERR

echo "$LOG Starting backup..."
mkdir -p "$BACKUP_DIR"

# Sanity check
echo "$LOG Running sanity checker..."
cd "$INSTALL_DIR"
docker compose exec -T paperless document_sanity_checker 2>&1 | tail -5

# Export
echo "$LOG Exporting documents..."
docker compose exec -T paperless document_exporter ../export --zip -sm

EXPORT_FILE=$(ls -t "$INSTALL_DIR/export/export-"*.zip 2>/dev/null | head -1)
[ -z "$EXPORT_FILE" ] && { echo "$LOG ERROR: No export file"; hc_fail; exit 1; }

# Determine type
if [ "$DAY_OF_MONTH" = "01" ]; then
    TYPE="monthly"; NAME="paperless-monthly-${DATE}.zip"
elif [ "$DAY_OF_WEEK" = "7" ]; then
    TYPE="weekly"; NAME="paperless-weekly-${DATE}.zip"
else
    TYPE="daily"; NAME="paperless-daily-${DATE}.zip"
fi

cp "$EXPORT_FILE" "$BACKUP_DIR/$NAME"
echo "$LOG Created $TYPE backup: $NAME"

# Verify integrity
unzip -t "$BACKUP_DIR/$NAME" >/dev/null 2>&1 || { echo "$LOG Backup corrupted!"; hc_fail; exit 1; }

# Upload to cloud (if configured)
if [ -n "$RCLONE_REMOTE" ] && command -v rclone &>/dev/null; then
    echo "$LOG Uploading to $RCLONE_REMOTE ($TYPE)..."
    rclone copy "$BACKUP_DIR/$NAME" "$RCLONE_REMOTE:$RCLONE_BACKUP_DIR/$TYPE/" --progress
    echo "$LOG Upload complete"

    # Rotate
    rclone delete "$RCLONE_REMOTE:$RCLONE_BACKUP_DIR/daily/" --min-age 7d 2>/dev/null || true
    rclone delete "$RCLONE_REMOTE:$RCLONE_BACKUP_DIR/weekly/" --min-age 28d 2>/dev/null || true
    rclone delete "$RCLONE_REMOTE:$RCLONE_BACKUP_DIR/monthly/" --min-age 90d 2>/dev/null || true
fi

# Encrypted GitHub backup (if configured)
if [ -n "$GITHUB_BACKUP_REPO" ] && [ -n "$ENCRYPTION_PASSPHRASE" ]; then
    ENCRYPTED="$BACKUP_DIR/${NAME}.enc"
    echo "$LOG Encrypting for GitHub..."
    openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in "$BACKUP_DIR/$NAME" -out "$ENCRYPTED" \
        -pass pass:"$ENCRYPTION_PASSPHRASE"

    if [ -d "$INSTALL_DIR/backup-repo" ]; then
        mkdir -p "$INSTALL_DIR/backup-repo/encrypted-backups/$TYPE"
        cp "$ENCRYPTED" "$INSTALL_DIR/backup-repo/encrypted-backups/$TYPE/"

        # Rotate encrypted backups
        find "$INSTALL_DIR/backup-repo/encrypted-backups/daily" -name "*.enc" -mtime +7 -delete 2>/dev/null || true
        find "$INSTALL_DIR/backup-repo/encrypted-backups/weekly" -name "*.enc" -mtime +28 -delete 2>/dev/null || true
        find "$INSTALL_DIR/backup-repo/encrypted-backups/monthly" -name "*.enc" -mtime +90 -delete 2>/dev/null || true

        cd "$INSTALL_DIR/backup-repo"
        git add -A
        git diff --staged --quiet || git commit -m "Backup $DATE - $TYPE (encrypted)" && git push origin main 2>/dev/null || true
    fi
    rm -f "$ENCRYPTED"
fi

# Cleanup
find "$INSTALL_DIR/export" -name "export-*.zip" -mtime +1 -delete 2>/dev/null || true
rm -f "$BACKUP_DIR/$NAME"

hc_ok
echo "$LOG Backup complete!"
BACKUPEOF
chmod +x "$INSTALL_DIR/backup.sh"

# ── restore.sh ────────────────────────────────────────────────
cat > "$INSTALL_DIR/restore.sh" << 'RESTOREEOF'
#!/bin/bash
# Paperless Overconfigured — Interactive Restore

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env" 2>/dev/null || true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "\n${BLUE}══════════════════════════════════════${NC}"
echo -e "${BLUE}  Paperless Overconfigured — Restore${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}\n"

echo "Restore from:"
echo "  1) Cloud backup (rclone — Google Drive, Dropbox, etc.)"
echo "  2) Encrypted backup (.enc file)"
echo "  3) Local backup (.zip file)"
echo "  4) List available backups"
echo ""
read -p "Choice [1-4]: " SRC

case "$SRC" in
    1)
        if [ -z "$RCLONE_REMOTE" ]; then
            err "No rclone remote configured in .env"
            exit 1
        fi
        echo ""
        echo "Available backups on $RCLONE_REMOTE:"
        for type in daily weekly monthly; do
            echo -e "\n  ${GREEN}$type:${NC}"
            rclone ls "$RCLONE_REMOTE:$RCLONE_BACKUP_DIR/$type/" 2>/dev/null | sort -t'-' -k3 -r | head -5 | sed 's/^/    /'
        done
        echo ""
        read -p "Backup type (daily/weekly/monthly): " BTYPE
        read -p "Filename: " BFILE
        mkdir -p "$INSTALL_DIR/backups"
        rclone copy "$RCLONE_REMOTE:$RCLONE_BACKUP_DIR/$BTYPE/$BFILE" "$INSTALL_DIR/backups/" --progress
        RESTORE_FILE="$INSTALL_DIR/backups/$BFILE"
        ;;
    2)
        read -p "Path to .enc file: " ENC_FILE
        [ -f "$ENC_FILE" ] || { err "File not found"; exit 1; }
        if [ -z "$ENCRYPTION_PASSPHRASE" ]; then
            read -sp "Decryption passphrase: " ENCRYPTION_PASSPHRASE; echo
        fi
        RESTORE_FILE="${ENC_FILE%.enc}"
        openssl enc -aes-256-cbc -d -salt -pbkdf2 \
            -in "$ENC_FILE" -out "$RESTORE_FILE" \
            -pass pass:"$ENCRYPTION_PASSPHRASE"
        ok "Decrypted"
        ;;
    3)
        read -p "Path to .zip file: " RESTORE_FILE
        [ -f "$RESTORE_FILE" ] || { err "File not found"; exit 1; }
        ;;
    4)
        echo -e "\n${BLUE}Local backups:${NC}"
        ls -lh "$INSTALL_DIR/backups/"*.zip 2>/dev/null | awk '{print "  " $5 "  " $9}' || echo "  (none)"
        if [ -n "$RCLONE_REMOTE" ]; then
            echo -e "\n${BLUE}Cloud backups ($RCLONE_REMOTE):${NC}"
            for type in daily weekly monthly; do
                echo -e "  ${GREEN}$type:${NC}"
                rclone ls "$RCLONE_REMOTE:$RCLONE_BACKUP_DIR/$type/" 2>/dev/null | sort -t'-' -k3 -r | head -3 | sed 's/^/    /'
            done
        fi
        exit 0
        ;;
    *) err "Invalid choice"; exit 1 ;;
esac

# Verify
echo ""
unzip -t "$RESTORE_FILE" >/dev/null 2>&1 || { err "Invalid backup file"; exit 1; }
ok "Backup integrity verified"

DOC_COUNT=$(unzip -l "$RESTORE_FILE" | grep -c '\.pdf\|\.png\|\.jpg\|\.webp' || true)
echo "  Contains ~$DOC_COUNT document files"
echo ""
echo -e "${YELLOW}This will REPLACE all current Paperless data!${NC}"
read -p "Type 'yes' to confirm: " CONFIRM
[ "$CONFIRM" = "yes" ] || { echo "Aborted."; exit 0; }

TS=$(date +%Y%m%d-%H%M%S)
cd "$INSTALL_DIR"

echo "Stopping Paperless..."
docker compose down

echo "Preserving current data..."
[ -d db ]    && sudo mv db    "db-pre-restore-$TS"
[ -d data ]  && sudo mv data  "data-pre-restore-$TS"
[ -d media ] && sudo mv media "media-pre-restore-$TS"
mkdir -p db data media

echo "Extracting backup..."
rm -rf export && mkdir -p export
unzip -q "$RESTORE_FILE" -d export/

echo "Starting stack..."
docker compose up -d

echo "Waiting for initialization (60s)..."
sleep 60

echo "Importing..."
docker compose exec -T paperless document_importer ../export

rm -rf export/

echo ""
ok "Restore complete!"
echo ""
warn "Post-restore checklist:"
echo "  1. API tokens are NOT restored — regenerate in Admin > Tokens"
echo "  2. Update PAPERLESS_API_TOKEN in .env"
echo "  3. Verify documents: docker compose exec paperless python3 manage.py shell -c"
echo "     \"from documents.models import Document; print(Document.objects.count())\""
RESTOREEOF
chmod +x "$INSTALL_DIR/restore.sh"

# ── restore-test.sh ───────────────────────────────────────────
cat > "$INSTALL_DIR/restore-test.sh" << 'TESTEOF'
#!/bin/bash
# Non-destructive backup verification

set -e
[ -z "$1" ] && { echo "Usage: $0 <backup.zip>"; exit 1; }
[ ! -f "$1" ] && { echo "File not found: $1"; exit 1; }

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

echo "[1/4] Checking integrity..."
unzip -t "$1" >/dev/null 2>&1 && echo "  OK" || { echo "  FAILED"; exit 1; }

echo "[2/4] Extracting..."
unzip -q "$1" -d "$TMP"
echo "  $(find "$TMP" -type f | wc -l) files"

echo "[3/4] Checking manifest..."
if [ -f "$TMP/manifest.json" ]; then
    DOCS=$(grep -c '"model": "documents.document"' "$TMP/manifest.json" || true)
    echo "  $DOCS documents in manifest"
else
    echo "  MISSING manifest.json!"; exit 1
fi

echo "[4/4] Sizes..."
echo "  Compressed: $(du -sh "$1" | cut -f1)"
echo "  Extracted: $(du -sh "$TMP" | cut -f1)"

echo ""
echo "RESTORE TEST PASSED"
TESTEOF
chmod +x "$INSTALL_DIR/restore-test.sh"

success "Backup and restore scripts created"

# ══════════════════════════════════════════════════════════════
# PHASE 7: CONFIGURE RCLONE (if backup enabled)
# ══════════════════════════════════════════════════════════════

if [ "$ENABLE_BACKUPS" = "true" ] && [ -n "$RCLONE_REMOTE" ] && [ "$RCLONE_PROVIDER" != "local" ] && [ "$RCLONE_PROVIDER" != "custom" ]; then
    if ! rclone listremotes 2>/dev/null | grep -q "^${RCLONE_REMOTE}:"; then
        step "Setting up cloud backup ($RCLONE_REMOTE)..."
        echo ""
        echo -e "${DIM}rclone needs to authenticate with your cloud provider.${NC}"
        echo -e "${DIM}This will open a browser for OAuth login.${NC}"
        echo ""
        prompt "Configure $RCLONE_REMOTE now? (Y/n): "
        read -r setup_rclone
        if [[ ! "$setup_rclone" =~ ^[Nn] ]]; then
            case "$RCLONE_PROVIDER" in
                drive)
                    echo -e "${DIM}Setting up Google Drive...${NC}"
                    rclone config create "$RCLONE_REMOTE" drive scope=drive
                    ;;
                dropbox)
                    echo -e "${DIM}Setting up Dropbox...${NC}"
                    rclone config create "$RCLONE_REMOTE" dropbox
                    ;;
                onedrive)
                    echo -e "${DIM}Setting up OneDrive...${NC}"
                    rclone config create "$RCLONE_REMOTE" onedrive
                    ;;
            esac
            success "Cloud backup configured"
        else
            warn "Skipped. Run 'rclone config' later to set up cloud backup."
        fi
    else
        success "rclone remote '$RCLONE_REMOTE' already configured"
    fi
fi

# ══════════════════════════════════════════════════════════════
# PHASE 8: SET UP BACKUP CRON
# ══════════════════════════════════════════════════════════════

if [ "$ENABLE_BACKUPS" = "true" ]; then
    step "Setting up backup schedule..."
    CRON_LINE="0 3 * * * $INSTALL_DIR/backup.sh >> $INSTALL_DIR/backup.log 2>&1"

    if crontab -l 2>/dev/null | grep -qF "backup.sh"; then
        success "Backup cron already exists"
    else
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
        success "Backup scheduled: daily at 3:00 AM"
    fi
fi

# ══════════════════════════════════════════════════════════════
# PHASE 9: START THE STACK
# ══════════════════════════════════════════════════════════════

step "Starting Paperless Overconfigured..."
cd "$INSTALL_DIR"

info "Pulling Docker images (this may take a few minutes)..."
docker compose pull

info "Starting services..."
docker compose up -d

info "Waiting for Paperless to become healthy..."
HEALTHY=false
for i in $(seq 1 60); do
    STATUS=$(docker inspect paperless-ngx --format '{{.State.Health.Status}}' 2>/dev/null || echo "starting")
    if [ "$STATUS" = "healthy" ]; then
        HEALTHY=true
        break
    fi
    sleep 5
    echo -ne "\r  ${DIM}Status: $STATUS ($((i*5))s)${NC}  "
done
echo ""

if [ "$HEALTHY" = "true" ]; then
    success "Paperless is healthy!"
else
    warn "Paperless is still starting. Give it a few more minutes."
fi

# ══════════════════════════════════════════════════════════════
# PHASE 10: SUMMARY
# ══════════════════════════════════════════════════════════════

echo ""
echo -e "${GREEN}${BOLD}"
cat << 'DONE'
  ╔══════════════════════════════════════════════════╗
  ║   Paperless Overconfigured is running!           ║
  ╚══════════════════════════════════════════════════╝
DONE
echo -e "${NC}"

echo -e "  ${BOLD}Services:${NC}"
docker ps --filter "network=paperless-net" --format '    {{.Names}}: {{.Status}}' 2>/dev/null || \
docker ps --format '    {{.Names}}: {{.Status}}' | grep -i paperless

echo ""
echo -e "  ${BOLD}Access:${NC}"
case "$ACCESS_METHOD" in
    tailscale)
        [ -n "$TAILSCALE_HOSTNAME" ] && echo "    Paperless: https://$TAILSCALE_HOSTNAME:8000"
        ;;
    cloudflare)
        [ -n "$PAPERLESS_DOMAIN" ] && echo "    Paperless: https://$PAPERLESS_DOMAIN"
        ;;
    both)
        [ -n "$TAILSCALE_HOSTNAME" ] && echo "    Paperless (Tailscale): https://$TAILSCALE_HOSTNAME:8000"
        [ -n "$PAPERLESS_DOMAIN" ] && echo "    Paperless (Domain):    https://$PAPERLESS_DOMAIN"
        ;;
    local)
        echo "    Paperless: http://localhost:8000"
        ;;
    exposed)
        echo "    Paperless: http://$(curl -s4 ifconfig.me 2>/dev/null || echo 'YOUR_IP'):8000"
        ;;
esac

if [[ "$COMPOSE_PROFILES" == *"ai"* ]]; then
    echo "    paperless-gpt: http://localhost:8080"
fi

echo ""
echo -e "  ${BOLD}Admin:${NC} $ADMIN_USER / (your password)"
echo ""
echo -e "  ${BOLD}Files:${NC}"
echo "    Config:     $INSTALL_DIR/.env"
echo "    Data:       $INSTALL_DIR/media/"
echo "    Import:     $INSTALL_DIR/consume/"
echo "    Backup:     $INSTALL_DIR/backup.sh"
echo "    Restore:    $INSTALL_DIR/restore.sh"
echo ""

if [ "$LLM_PROVIDER" != "none" ] && [[ "$COMPOSE_PROFILES" == *"ai"* ]]; then
    echo -e "  ${BOLD}Next steps:${NC}"
    echo "    1. Open Paperless and upload your first document"
    echo "    2. Generate an API token: Admin > Tokens"
    echo "    3. Add the token to .env: PAPERLESS_API_TOKEN=your-token"
    echo "    4. Restart: cd $INSTALL_DIR && docker compose up -d"
else
    echo -e "  ${BOLD}Next steps:${NC}"
    echo "    1. Open Paperless and upload your first document"
fi

if [ "$ENABLE_BACKUPS" = "true" ] && [ -n "$RCLONE_REMOTE" ]; then
    if ! rclone listremotes 2>/dev/null | grep -q "^${RCLONE_REMOTE}:"; then
        echo "    - Configure cloud backup: rclone config"
    fi
fi

echo ""
echo -e "  ${DIM}To reconfigure: edit $INSTALL_DIR/.env and run 'docker compose up -d'${NC}"
echo -e "  ${DIM}To stop: cd $INSTALL_DIR && docker compose down${NC}"
echo -e "  ${DIM}To update: cd $INSTALL_DIR && docker compose pull && docker compose up -d${NC}"
echo -e "  ${DIM}To uninstall: cd $INSTALL_DIR && ./uninstall.sh${NC}"
echo ""
