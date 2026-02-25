#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Paperless Overconfigured — Uninstaller                      ║
# ║                                                              ║
# ║  Safely removes the Paperless stack and optionally cleans    ║
# ║  up all data, backups, and system configurations.            ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ── Detect install directory ──────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/docker-compose.yml" ] && [ -f "$SCRIPT_DIR/.env" ]; then
    INSTALL_DIR="$SCRIPT_DIR"
elif [ -f "$HOME/paperless/docker-compose.yml" ]; then
    INSTALL_DIR="$HOME/paperless"
else
    echo -e "${RED}Could not find Paperless installation.${NC}"
    echo "Expected docker-compose.yml in current directory or ~/paperless/"
    exit 1
fi

echo -e "${RED}${BOLD}"
cat << 'BANNER'

  ╔══════════════════════════════════════════════════╗
  ║   Paperless Overconfigured — Uninstaller         ║
  ╚══════════════════════════════════════════════════╝

BANNER
echo -e "${NC}"

echo -e "  ${BOLD}Installation found:${NC} $INSTALL_DIR"
echo ""

# ── Check what's running ──────────────────────────────────────
cd "$INSTALL_DIR"

if docker compose ps --quiet 2>/dev/null | grep -q .; then
    echo -e "  ${BOLD}Running services:${NC}"
    docker compose ps --format '    {{.Name}}: {{.Status}}' 2>/dev/null || true
    echo ""
fi

# ── Confirm ───────────────────────────────────────────────────
echo -e "${YELLOW}${BOLD}What would you like to remove?${NC}"
echo ""
echo -e "  ${CYAN}1)${NC} Stop containers only (keep all data and config)"
echo -e "  ${CYAN}2)${NC} Stop containers + remove Docker volumes (database, Redis)"
echo -e "  ${CYAN}3)${NC} Full removal (containers, volumes, config, and ALL data)"
echo -e "  ${CYAN}4)${NC} Cancel"
echo ""
echo -ne "${BOLD}Enter choice [1-4]: ${NC}"
read -r choice

case "$choice" in
    1)
        echo ""
        info "Stopping containers..."
        docker compose down
        success "Containers stopped. Your data and config remain in $INSTALL_DIR"
        echo -e "  ${DIM}To restart: cd $INSTALL_DIR && docker compose up -d${NC}"
        ;;
    2)
        echo ""
        warn "This will destroy your PostgreSQL database and Redis data."
        echo -ne "${RED}${BOLD}Type 'yes' to confirm: ${NC}"
        read -r confirm
        if [ "$confirm" != "yes" ]; then
            echo "Aborted."
            exit 0
        fi
        info "Stopping containers and removing volumes..."
        docker compose down -v
        success "Containers stopped, Docker volumes removed."
        echo -e "  ${DIM}Your files remain in $INSTALL_DIR (media, config, scripts)${NC}"
        ;;
    3)
        echo ""
        echo -e "${RED}${BOLD}WARNING: This will permanently delete:${NC}"
        echo -e "  - All Docker containers and volumes"
        echo -e "  - All documents in $INSTALL_DIR/media/"
        echo -e "  - Database, config, scripts, everything in $INSTALL_DIR/"
        echo -e "  - Backup cron job (if configured)"
        echo ""

        # Show data sizes
        if [ -d "$INSTALL_DIR/media" ]; then
            MEDIA_SIZE=$(du -sh "$INSTALL_DIR/media/" 2>/dev/null | cut -f1)
            echo -e "  ${BOLD}Documents:${NC} $MEDIA_SIZE in $INSTALL_DIR/media/"
        fi
        TOTAL_SIZE=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)
        echo -e "  ${BOLD}Total:${NC} $TOTAL_SIZE in $INSTALL_DIR/"
        echo ""

        echo -e "${RED}Have you backed up your documents? This cannot be undone.${NC}"
        echo -ne "${RED}${BOLD}Type 'DELETE EVERYTHING' to confirm: ${NC}"
        read -r confirm
        if [ "$confirm" != "DELETE EVERYTHING" ]; then
            echo "Aborted."
            exit 0
        fi

        info "Stopping containers and removing volumes..."
        docker compose down -v 2>/dev/null || true

        # Remove backup cron
        if crontab -l 2>/dev/null | grep -qF "$INSTALL_DIR/backup.sh"; then
            info "Removing backup cron job..."
            crontab -l 2>/dev/null | grep -vF "$INSTALL_DIR/backup.sh" | crontab - 2>/dev/null || true
            success "Backup cron removed"
        fi

        # Remove neo4j sync cron
        if crontab -l 2>/dev/null | grep -qF "neo4j-sync.py"; then
            info "Removing Neo4j sync cron job..."
            crontab -l 2>/dev/null | grep -vF "neo4j-sync.py" | crontab - 2>/dev/null || true
            success "Neo4j sync cron removed"
        fi

        # Remove Docker images (optional)
        echo ""
        echo -ne "${BOLD}Also remove downloaded Docker images? (y/N): ${NC}"
        read -r remove_images
        if [[ "$remove_images" =~ ^[Yy] ]]; then
            info "Removing Docker images..."
            docker compose config --images 2>/dev/null | while read -r image; do
                docker rmi "$image" 2>/dev/null || true
            done
            success "Docker images removed"
        fi

        # Remove installation directory
        info "Removing $INSTALL_DIR..."
        cd /
        rm -rf "$INSTALL_DIR"
        success "Installation directory removed"

        echo ""
        echo -e "${GREEN}${BOLD}Paperless Overconfigured has been completely removed.${NC}"
        echo ""
        echo -e "${DIM}Note: Docker itself was not removed. To remove Docker:${NC}"
        echo -e "${DIM}  Ubuntu/Debian: sudo apt remove docker-ce docker-ce-cli${NC}"
        echo -e "${DIM}  macOS: Remove Docker Desktop from Applications${NC}"
        echo ""
        ;;
    4|*)
        echo "Cancelled."
        exit 0
        ;;
esac
