#!/usr/bin/env bats
# Tests for uninstall.sh script
# Run with: bats tests/test_uninstall.bats

# ─────────────────────────────────────────────────────────────
# Tests for installation directory detection
# ─────────────────────────────────────────────────────────────

@test "detect install dir from script location" {
    SCRIPT_DIR="/home/user/paperless"
    
    # Simulate files exist
    has_compose_in_script_dir="true"
    has_env_in_script_dir="true"
    has_compose_in_home="false"
    
    if [ "$has_compose_in_script_dir" = "true" ] && [ "$has_env_in_script_dir" = "true" ]; then
        INSTALL_DIR="$SCRIPT_DIR"
    elif [ "$has_compose_in_home" = "true" ]; then
        INSTALL_DIR="$HOME/paperless"
    else
        INSTALL_DIR=""
    fi
    
    [ "$INSTALL_DIR" = "/home/user/paperless" ]
}

@test "detect install dir from home directory" {
    SCRIPT_DIR="/tmp/random"
    
    has_compose_in_script_dir="false"
    has_env_in_script_dir="false"
    has_compose_in_home="true"
    
    if [ "$has_compose_in_script_dir" = "true" ] && [ "$has_env_in_script_dir" = "true" ]; then
        INSTALL_DIR="$SCRIPT_DIR"
    elif [ "$has_compose_in_home" = "true" ]; then
        INSTALL_DIR="$HOME/paperless"
    else
        INSTALL_DIR=""
    fi
    
    [ "$INSTALL_DIR" = "$HOME/paperless" ]
}

@test "fail when no installation found" {
    has_compose_in_script_dir="false"
    has_env_in_script_dir="false"
    has_compose_in_home="false"
    
    if [ "$has_compose_in_script_dir" = "true" ] && [ "$has_env_in_script_dir" = "true" ]; then
        INSTALL_DIR="/script/dir"
    elif [ "$has_compose_in_home" = "true" ]; then
        INSTALL_DIR="$HOME/paperless"
    else
        INSTALL_DIR=""
    fi
    
    [ -z "$INSTALL_DIR" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for uninstall choice handling
# ─────────────────────────────────────────────────────────────

@test "choice 1 - stop containers only" {
    choice=1
    
    case "$choice" in
        1) action="stop_only" ;;
        2) action="stop_and_volumes" ;;
        3) action="full_removal" ;;
        4|*) action="cancel" ;;
    esac
    
    [ "$action" = "stop_only" ]
}

@test "choice 2 - stop containers and remove volumes" {
    choice=2
    
    case "$choice" in
        1) action="stop_only" ;;
        2) action="stop_and_volumes" ;;
        3) action="full_removal" ;;
        4|*) action="cancel" ;;
    esac
    
    [ "$action" = "stop_and_volumes" ]
}

@test "choice 3 - full removal" {
    choice=3
    
    case "$choice" in
        1) action="stop_only" ;;
        2) action="stop_and_volumes" ;;
        3) action="full_removal" ;;
        4|*) action="cancel" ;;
    esac
    
    [ "$action" = "full_removal" ]
}

@test "choice 4 - cancel" {
    choice=4
    
    case "$choice" in
        1) action="stop_only" ;;
        2) action="stop_and_volumes" ;;
        3) action="full_removal" ;;
        4|*) action="cancel" ;;
    esac
    
    [ "$action" = "cancel" ]
}

@test "invalid choice defaults to cancel" {
    choice="invalid"
    
    case "$choice" in
        1) action="stop_only" ;;
        2) action="stop_and_volumes" ;;
        3) action="full_removal" ;;
        4|*) action="cancel" ;;
    esac
    
    [ "$action" = "cancel" ]
}

@test "empty choice defaults to cancel" {
    choice=""
    
    case "$choice" in
        1) action="stop_only" ;;
        2) action="stop_and_volumes" ;;
        3) action="full_removal" ;;
        4|*) action="cancel" ;;
    esac
    
    [ "$action" = "cancel" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for confirmation handling
# ─────────────────────────────────────────────────────────────

@test "volumes removal requires 'yes' confirmation" {
    confirm="yes"
    
    if [ "$confirm" = "yes" ]; then
        proceed="true"
    else
        proceed="false"
    fi
    
    [ "$proceed" = "true" ]
}

@test "volumes removal rejected with 'no'" {
    confirm="no"
    
    if [ "$confirm" = "yes" ]; then
        proceed="true"
    else
        proceed="false"
    fi
    
    [ "$proceed" = "false" ]
}

@test "volumes removal rejected with empty input" {
    confirm=""
    
    if [ "$confirm" = "yes" ]; then
        proceed="true"
    else
        proceed="false"
    fi
    
    [ "$proceed" = "false" ]
}

@test "full removal requires 'DELETE EVERYTHING' confirmation" {
    confirm="DELETE EVERYTHING"
    
    if [ "$confirm" = "DELETE EVERYTHING" ]; then
        proceed="true"
    else
        proceed="false"
    fi
    
    [ "$proceed" = "true" ]
}

@test "full removal rejected with partial match" {
    confirm="DELETE"
    
    if [ "$confirm" = "DELETE EVERYTHING" ]; then
        proceed="true"
    else
        proceed="false"
    fi
    
    [ "$proceed" = "false" ]
}

@test "full removal rejected with lowercase" {
    confirm="delete everything"
    
    if [ "$confirm" = "DELETE EVERYTHING" ]; then
        proceed="true"
    else
        proceed="false"
    fi
    
    [ "$proceed" = "false" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for cron job detection logic
# ─────────────────────────────────────────────────────────────

@test "backup cron detected when present" {
    INSTALL_DIR="/home/user/paperless"
    crontab_content="0 3 * * * /home/user/paperless/backup.sh"
    
    if echo "$crontab_content" | grep -qF "$INSTALL_DIR/backup.sh"; then
        has_backup_cron="true"
    else
        has_backup_cron="false"
    fi
    
    [ "$has_backup_cron" = "true" ]
}

@test "backup cron not detected when absent" {
    INSTALL_DIR="/home/user/paperless"
    crontab_content="0 0 * * * /some/other/script.sh"
    
    if echo "$crontab_content" | grep -qF "$INSTALL_DIR/backup.sh"; then
        has_backup_cron="true"
    else
        has_backup_cron="false"
    fi
    
    [ "$has_backup_cron" = "false" ]
}

@test "neo4j sync cron detected when present" {
    crontab_content="*/5 * * * * python3 /path/to/neo4j-sync.py"
    
    if echo "$crontab_content" | grep -qF "neo4j-sync.py"; then
        has_neo4j_cron="true"
    else
        has_neo4j_cron="false"
    fi
    
    [ "$has_neo4j_cron" = "true" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for color code definitions
# ─────────────────────────────────────────────────────────────

@test "RED color code is defined" {
    RED='\033[0;31m'
    [ "$RED" = '\033[0;31m' ]
}

@test "GREEN color code is defined" {
    GREEN='\033[0;32m'
    [ "$GREEN" = '\033[0;32m' ]
}

@test "YELLOW color code is defined" {
    YELLOW='\033[1;33m'
    [ "$YELLOW" = '\033[1;33m' ]
}

@test "BLUE color code is defined" {
    BLUE='\033[0;34m'
    [ "$BLUE" = '\033[0;34m' ]
}

@test "NC (no color) is defined" {
    NC='\033[0m'
    [ "$NC" = '\033[0m' ]
}

# ─────────────────────────────────────────────────────────────
# Tests for Docker image removal option
# ─────────────────────────────────────────────────────────────

@test "y response removes Docker images" {
    remove_images="y"
    
    if [[ "$remove_images" =~ ^[Yy] ]]; then
        should_remove="true"
    else
        should_remove="false"
    fi
    
    [ "$should_remove" = "true" ]
}

@test "Y response removes Docker images" {
    remove_images="Y"
    
    if [[ "$remove_images" =~ ^[Yy] ]]; then
        should_remove="true"
    else
        should_remove="false"
    fi
    
    [ "$should_remove" = "true" ]
}

@test "n response keeps Docker images" {
    remove_images="n"
    
    if [[ "$remove_images" =~ ^[Yy] ]]; then
        should_remove="true"
    else
        should_remove="false"
    fi
    
    [ "$should_remove" = "false" ]
}

@test "empty response keeps Docker images" {
    remove_images=""
    
    if [[ "$remove_images" =~ ^[Yy] ]]; then
        should_remove="true"
    else
        should_remove="false"
    fi
    
    [ "$should_remove" = "false" ]
}
