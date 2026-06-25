#!/usr/bin/env bash
#
# pi5-stack setup helper
# Checks prerequisites, creates .env from example, and starts the stack.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_command() {
    if ! command -v "$1" &>/dev/null; then
        error "Required command '$1' not found. Install it first."
    fi
}

check_docker() {
    check_command docker
    if ! docker info &>/dev/null; then
        error "Docker daemon is not running. Start it with: sudo systemctl start docker"
    fi
    info "Docker is running."
}

check_compose() {
    if docker compose version &>/dev/null; then
        info "Docker Compose (plugin) found."
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &>/dev/null; then
        info "Docker Compose (standalone) found."
        COMPOSE_CMD="docker-compose"
    else
        error "Docker Compose not found. Install the docker-compose-plugin package."
    fi
}

check_arch() {
    local arch
    arch="$(uname -m)"
    if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        info "Running on ARM64 ($arch). Images are compatible."
    else
        warn "Running on $arch, not ARM64. Images may not work on a Raspberry Pi."
    fi
}

setup_env() {
    if [[ -f .env ]]; then
        info ".env file already exists. Skipping copy."
    else
        if [[ -f .env.example ]]; then
            cp .env.example .env
            warn ".env created from .env.example. Edit it with your real passwords and domain!"
            warn "Run: nano .env"
            exit 0
        else
            error ".env.example not found. Cannot create .env."
        fi
    fi

    # Check for default passwords
    if grep -q 'changeme' .env; then
        error "Found 'changeme' in .env. Edit it with real values before starting."
    fi
}

start_stack() {
    info "Pulling images..."
    $COMPOSE_CMD pull

    info "Starting Pi5 Stack..."
    $COMPOSE_CMD up -d

    info "All services started. Here are the default ports:"
    echo ""
    echo "  Nextcloud:    https://your-domain  (Caddy reverse proxy)"
    echo "  Nextcloud:    http://pi-ip:8080    (direct)"
    echo "  Pi-hole:      http://pi-ip:8081/admin"
    echo "  Uptime Kuma:  http://pi-ip:3001"
    echo ""
    info "Check status:  $COMPOSE_CMD ps"
    info "View logs:     $COMPOSE_CMD logs -f"
}

stop_stack() {
    info "Stopping Pi5 Stack..."
    $COMPOSE_CMD down
    info "Stack stopped. Data volumes are preserved."
}

backup_data() {
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    info "Exporting volume data to $backup_dir..."

    local volumes=(
        "pi5-stack_nextcloud_data"
        "pi5-stack_nextcloud_db"
        "pi5-stack_pihole_etc"
        "pi5-stack_pihole_dnsmasq"
        "pi5-stack_uptime_kuma"
    )

    for vol in "${volumes[@]}"; do
        docker run --rm -v "$vol:/source" -v "$SCRIPT_DIR/$backup_dir:/backup" \
            alpine tar czf "/backup/${vol}.tar.gz" -C /source .
        info "Backed up $vol"
    done

    info "Backup complete in $backup_dir/"
}

show_help() {
    echo "pi5-stack setup helper"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start    Check prerequisites and start all services (default)"
    echo "  stop     Stop all services (preserves data)"
    echo "  backup   Export volume data to backups/ directory"
    echo "  help     Show this help message"
    echo ""
}

# Main
COMMAND="${1:-start}"

case "$COMMAND" in
    start)
        check_docker
        check_compose
        check_arch
        setup_env
        start_stack
        ;;
    stop)
        check_docker
        check_compose
        stop_stack
        ;;
    backup)
        check_docker
        backup_data
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $COMMAND. Run '$0 help' for usage."
        ;;
esac
