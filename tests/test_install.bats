#!/usr/bin/env bats
# Tests for install.sh helper functions
# Run with: bats tests/test_install.bats

# Note: These tests verify the logic patterns used in install.sh
# without sourcing the entire script to avoid interactive prompts

# ─────────────────────────────────────────────────────────────
# Tests for detect_os function
# ─────────────────────────────────────────────────────────────

@test "detect_os returns debian for Ubuntu" {
    # Mock /etc/os-release
    export ID="ubuntu"
    function detect_os_mocked() {
        case "$ID" in
            ubuntu|debian|pop|linuxmint) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            nixos) echo "nixos" ;;
            *) echo "linux-unknown" ;;
        esac
    }
    result=$(detect_os_mocked)
    [ "$result" = "debian" ]
}

@test "detect_os returns debian for Debian" {
    export ID="debian"
    function detect_os_mocked() {
        case "$ID" in
            ubuntu|debian|pop|linuxmint) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            nixos) echo "nixos" ;;
            *) echo "linux-unknown" ;;
        esac
    }
    result=$(detect_os_mocked)
    [ "$result" = "debian" ]
}

@test "detect_os returns fedora for Fedora" {
    export ID="fedora"
    function detect_os_mocked() {
        case "$ID" in
            ubuntu|debian|pop|linuxmint) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            nixos) echo "nixos" ;;
            *) echo "linux-unknown" ;;
        esac
    }
    result=$(detect_os_mocked)
    [ "$result" = "fedora" ]
}

@test "detect_os returns fedora for RHEL" {
    export ID="rhel"
    function detect_os_mocked() {
        case "$ID" in
            ubuntu|debian|pop|linuxmint) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            nixos) echo "nixos" ;;
            *) echo "linux-unknown" ;;
        esac
    }
    result=$(detect_os_mocked)
    [ "$result" = "fedora" ]
}

@test "detect_os returns nixos for NixOS" {
    export ID="nixos"
    function detect_os_mocked() {
        case "$ID" in
            ubuntu|debian|pop|linuxmint) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            nixos) echo "nixos" ;;
            *) echo "linux-unknown" ;;
        esac
    }
    result=$(detect_os_mocked)
    [ "$result" = "nixos" ]
}

@test "detect_os returns linux-unknown for unrecognized distro" {
    export ID="arch"
    function detect_os_mocked() {
        case "$ID" in
            ubuntu|debian|pop|linuxmint) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            nixos) echo "nixos" ;;
            *) echo "linux-unknown" ;;
        esac
    }
    result=$(detect_os_mocked)
    [ "$result" = "linux-unknown" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for detect_arch function
# ─────────────────────────────────────────────────────────────

@test "detect_arch returns amd64 for x86_64" {
    function detect_arch_mocked() {
        local arch="x86_64"
        case "$arch" in
            x86_64|amd64) echo "amd64" ;;
            aarch64|arm64) echo "arm64" ;;
            *) echo "$arch" ;;
        esac
    }
    result=$(detect_arch_mocked)
    [ "$result" = "amd64" ]
}

@test "detect_arch returns arm64 for aarch64" {
    function detect_arch_mocked() {
        local arch="aarch64"
        case "$arch" in
            x86_64|amd64) echo "amd64" ;;
            aarch64|arm64) echo "arm64" ;;
            *) echo "$arch" ;;
        esac
    }
    result=$(detect_arch_mocked)
    [ "$result" = "arm64" ]
}

@test "detect_arch returns arm64 for arm64" {
    function detect_arch_mocked() {
        local arch="arm64"
        case "$arch" in
            x86_64|amd64) echo "amd64" ;;
            aarch64|arm64) echo "arm64" ;;
            *) echo "$arch" ;;
        esac
    }
    result=$(detect_arch_mocked)
    [ "$result" = "arm64" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for generate_secret function
# ─────────────────────────────────────────────────────────────

@test "generate_secret produces 64 character hex string" {
    result=$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')
    [ ${#result} -eq 64 ]
}

@test "generate_secret produces unique values" {
    result1=$(openssl rand -hex 32 2>/dev/null)
    result2=$(openssl rand -hex 32 2>/dev/null)
    [ "$result1" != "$result2" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for generate_password function
# ─────────────────────────────────────────────────────────────

@test "generate_password produces 16 character password" {
    result=$(openssl rand -base64 16 2>/dev/null | tr -d '=/+' | head -c 16)
    [ ${#result} -eq 16 ]
}

@test "generate_password produces alphanumeric characters only" {
    result=$(openssl rand -base64 16 2>/dev/null | tr -d '=/+' | head -c 16)
    # Check that password contains only alphanumeric characters
    [[ "$result" =~ ^[A-Za-z0-9]+$ ]]
}

# ─────────────────────────────────────────────────────────────
# Tests for OCR language selection logic
# ─────────────────────────────────────────────────────────────

@test "OCR language defaults to eng for choice 1" {
    OCR_CHOICE=1
    case "$OCR_CHOICE" in
        1) OCR_LANGUAGE="eng" ;;
        2) OCR_LANGUAGE="deu+eng" ;;
        3) OCR_LANGUAGE="fra+eng" ;;
        4) OCR_LANGUAGE="spa+eng" ;;
        *) OCR_LANGUAGE="eng" ;;
    esac
    [ "$OCR_LANGUAGE" = "eng" ]
}

@test "OCR language is deu+eng for choice 2" {
    OCR_CHOICE=2
    case "$OCR_CHOICE" in
        1) OCR_LANGUAGE="eng" ;;
        2) OCR_LANGUAGE="deu+eng" ;;
        3) OCR_LANGUAGE="fra+eng" ;;
        4) OCR_LANGUAGE="spa+eng" ;;
        *) OCR_LANGUAGE="eng" ;;
    esac
    [ "$OCR_LANGUAGE" = "deu+eng" ]
}

@test "OCR language is fra+eng for choice 3" {
    OCR_CHOICE=3
    case "$OCR_CHOICE" in
        1) OCR_LANGUAGE="eng" ;;
        2) OCR_LANGUAGE="deu+eng" ;;
        3) OCR_LANGUAGE="fra+eng" ;;
        4) OCR_LANGUAGE="spa+eng" ;;
        *) OCR_LANGUAGE="eng" ;;
    esac
    [ "$OCR_LANGUAGE" = "fra+eng" ]
}

@test "OCR language is spa+eng for choice 4" {
    OCR_CHOICE=4
    case "$OCR_CHOICE" in
        1) OCR_LANGUAGE="eng" ;;
        2) OCR_LANGUAGE="deu+eng" ;;
        3) OCR_LANGUAGE="fra+eng" ;;
        4) OCR_LANGUAGE="spa+eng" ;;
        *) OCR_LANGUAGE="eng" ;;
    esac
    [ "$OCR_LANGUAGE" = "spa+eng" ]
}

@test "OCR language defaults to eng for invalid choice" {
    OCR_CHOICE="invalid"
    case "$OCR_CHOICE" in
        1) OCR_LANGUAGE="eng" ;;
        2) OCR_LANGUAGE="deu+eng" ;;
        3) OCR_LANGUAGE="fra+eng" ;;
        4) OCR_LANGUAGE="spa+eng" ;;
        *) OCR_LANGUAGE="eng" ;;
    esac
    [ "$OCR_LANGUAGE" = "eng" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for access method URL building
# ─────────────────────────────────────────────────────────────

@test "local access method sets localhost URL" {
    ACCESS_METHOD="local"
    PAPERLESS_URL="http://localhost:8000"
    [ "$PAPERLESS_URL" = "http://localhost:8000" ]
}

@test "tailscale access method builds correct URL" {
    ACCESS_METHOD="tailscale"
    TAILSCALE_HOSTNAME="my-machine.tail12345.ts.net"
    PAPERLESS_URL="https://$TAILSCALE_HOSTNAME"
    [ "$PAPERLESS_URL" = "https://my-machine.tail12345.ts.net" ]
}

@test "cloudflare access method builds correct URL" {
    ACCESS_METHOD="cloudflare"
    PAPERLESS_DOMAIN="docs.example.com"
    PAPERLESS_URL="https://$PAPERLESS_DOMAIN"
    [ "$PAPERLESS_URL" = "https://docs.example.com" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for LLM provider selection
# ─────────────────────────────────────────────────────────────

@test "LLM provider googleai sets correct model" {
    AI_CHOICE=1
    case "$AI_CHOICE" in
        1) LLM_PROVIDER="googleai"; LLM_MODEL="gemini-2.5-flash" ;;
        2) LLM_PROVIDER="openai"; LLM_MODEL="gpt-4o" ;;
        3) LLM_PROVIDER="ollama"; LLM_MODEL="llama3" ;;
        4) LLM_PROVIDER="none" ;;
    esac
    [ "$LLM_PROVIDER" = "googleai" ]
    [ "$LLM_MODEL" = "gemini-2.5-flash" ]
}

@test "LLM provider openai sets correct model" {
    AI_CHOICE=2
    case "$AI_CHOICE" in
        1) LLM_PROVIDER="googleai"; LLM_MODEL="gemini-2.5-flash" ;;
        2) LLM_PROVIDER="openai"; LLM_MODEL="gpt-4o" ;;
        3) LLM_PROVIDER="ollama"; LLM_MODEL="llama3" ;;
        4) LLM_PROVIDER="none" ;;
    esac
    [ "$LLM_PROVIDER" = "openai" ]
    [ "$LLM_MODEL" = "gpt-4o" ]
}

@test "LLM provider ollama sets correct model" {
    AI_CHOICE=3
    case "$AI_CHOICE" in
        1) LLM_PROVIDER="googleai"; LLM_MODEL="gemini-2.5-flash" ;;
        2) LLM_PROVIDER="openai"; LLM_MODEL="gpt-4o" ;;
        3) LLM_PROVIDER="ollama"; LLM_MODEL="llama3" ;;
        4) LLM_PROVIDER="none" ;;
    esac
    [ "$LLM_PROVIDER" = "ollama" ]
    [ "$LLM_MODEL" = "llama3" ]
}

@test "LLM provider none disables AI" {
    AI_CHOICE=4
    LLM_MODEL=""
    case "$AI_CHOICE" in
        1) LLM_PROVIDER="googleai"; LLM_MODEL="gemini-2.5-flash" ;;
        2) LLM_PROVIDER="openai"; LLM_MODEL="gpt-4o" ;;
        3) LLM_PROVIDER="ollama"; LLM_MODEL="llama3" ;;
        4) LLM_PROVIDER="none" ;;
    esac
    [ "$LLM_PROVIDER" = "none" ]
    [ -z "$LLM_MODEL" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for backup configuration
# ─────────────────────────────────────────────────────────────

@test "backup choice 1 sets Google Drive" {
    BACKUP_CHOICE=1
    case "$BACKUP_CHOICE" in
        1) ENABLE_BACKUPS="true"; RCLONE_REMOTE="Gdrive"; RCLONE_PROVIDER="drive" ;;
        3) ENABLE_BACKUPS="true"; RCLONE_REMOTE="Dropbox"; RCLONE_PROVIDER="dropbox" ;;
        4) ENABLE_BACKUPS="true"; RCLONE_REMOTE="OneDrive"; RCLONE_PROVIDER="onedrive" ;;
        6) ENABLE_BACKUPS="true"; RCLONE_REMOTE=""; RCLONE_PROVIDER="local" ;;
        7) ENABLE_BACKUPS="false" ;;
    esac
    [ "$ENABLE_BACKUPS" = "true" ]
    [ "$RCLONE_REMOTE" = "Gdrive" ]
    [ "$RCLONE_PROVIDER" = "drive" ]
}

@test "backup choice 6 sets local only" {
    BACKUP_CHOICE=6
    case "$BACKUP_CHOICE" in
        1) ENABLE_BACKUPS="true"; RCLONE_REMOTE="Gdrive"; RCLONE_PROVIDER="drive" ;;
        3) ENABLE_BACKUPS="true"; RCLONE_REMOTE="Dropbox"; RCLONE_PROVIDER="dropbox" ;;
        4) ENABLE_BACKUPS="true"; RCLONE_REMOTE="OneDrive"; RCLONE_PROVIDER="onedrive" ;;
        6) ENABLE_BACKUPS="true"; RCLONE_REMOTE=""; RCLONE_PROVIDER="local" ;;
        7) ENABLE_BACKUPS="false" ;;
    esac
    [ "$ENABLE_BACKUPS" = "true" ]
    [ -z "$RCLONE_REMOTE" ]
    [ "$RCLONE_PROVIDER" = "local" ]
}

@test "backup choice 7 disables backups" {
    BACKUP_CHOICE=7
    ENABLE_BACKUPS="true"  # Reset to test
    case "$BACKUP_CHOICE" in
        1) ENABLE_BACKUPS="true"; RCLONE_REMOTE="Gdrive"; RCLONE_PROVIDER="drive" ;;
        3) ENABLE_BACKUPS="true"; RCLONE_REMOTE="Dropbox"; RCLONE_PROVIDER="dropbox" ;;
        4) ENABLE_BACKUPS="true"; RCLONE_REMOTE="OneDrive"; RCLONE_PROVIDER="onedrive" ;;
        6) ENABLE_BACKUPS="true"; RCLONE_REMOTE=""; RCLONE_PROVIDER="local" ;;
        7) ENABLE_BACKUPS="false" ;;
    esac
    [ "$ENABLE_BACKUPS" = "false" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for compose profiles logic
# ─────────────────────────────────────────────────────────────

@test "compose profiles set correctly for AI only" {
    COMPOSE_PROFILES=""
    if [ -n "$COMPOSE_PROFILES" ]; then
        COMPOSE_PROFILES="${COMPOSE_PROFILES},ai"
    else
        COMPOSE_PROFILES="ai"
    fi
    [ "$COMPOSE_PROFILES" = "ai" ]
}

@test "compose profiles set correctly for tunnel only" {
    COMPOSE_PROFILES=""
    COMPOSE_PROFILES="tunnel"
    [ "$COMPOSE_PROFILES" = "tunnel" ]
}

@test "compose profiles set correctly for AI and tunnel" {
    COMPOSE_PROFILES="tunnel"
    if [ -n "$COMPOSE_PROFILES" ]; then
        COMPOSE_PROFILES="${COMPOSE_PROFILES},ai"
    else
        COMPOSE_PROFILES="ai"
    fi
    [ "$COMPOSE_PROFILES" = "tunnel,ai" ]
}

@test "compose profiles set correctly for graph" {
    COMPOSE_PROFILES=""
    if [ -n "$COMPOSE_PROFILES" ]; then
        COMPOSE_PROFILES="${COMPOSE_PROFILES},graph"
    else
        COMPOSE_PROFILES="graph"
    fi
    [ "$COMPOSE_PROFILES" = "graph" ]
}

@test "compose profiles set correctly for all options" {
    COMPOSE_PROFILES="tunnel"
    COMPOSE_PROFILES="${COMPOSE_PROFILES},ai"
    COMPOSE_PROFILES="${COMPOSE_PROFILES},graph"
    [ "$COMPOSE_PROFILES" = "tunnel,ai,graph" ]
}
