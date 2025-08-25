#!/usr/bin/env bash
# Setup script for mirror-sync project

set -euo pipefail

# Load configuration and common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Fix for when running from project root - check if config exists in current dir
if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

# shellcheck source=../lib/common.sh
source "$PROJECT_ROOT/lib/common.sh"
load_config

# ========== Setup Functions ==========
check_prerequisites() {
    log_info "Checking prerequisites"
    
    local missing_tools=()
    
    # Check for container runtime
    if ! command -v podman >/dev/null && ! command -v docker >/dev/null; then
        missing_tools+=("podman or docker")
    fi
    
    # Check for systemd (if we're setting up services)
    if [[ "${SETUP_SYSTEMD:-true}" == "true" ]] && ! command -v systemctl >/dev/null; then
        missing_tools+=("systemctl")
    fi
    
    # Check for other utilities
    for tool in curl wget rsync; do
        if ! command -v "$tool" >/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install them before running setup"
        return 1
    fi
    
    log_info "All prerequisites satisfied"
}

create_directories() {
    log_info "Creating directory structure"
    
    # Create base directories
    sudo mkdir -p "$PROJECT_ROOT"
    sudo mkdir -p "$BASE_LOG_DIR"
    sudo mkdir -p "$BASE_MIRROR_DIR"
    
    # Create mirror-specific directories
    sudo mkdir -p "$DEBIAN_TARGET"
    sudo mkdir -p "$UBUNTU_TARGET" 
    sudo mkdir -p "$ROCKY_TARGET"
    
    # Create log directories
    sudo mkdir -p "$BASE_LOG_DIR/debian"
    sudo mkdir -p "$BASE_LOG_DIR/ubuntu"
    sudo mkdir -p "$BASE_LOG_DIR/rocky"
    
    # Set permissions
    sudo chown -R root:root "$PROJECT_ROOT"
    sudo chmod 755 "$PROJECT_ROOT"
    sudo chmod 755 "$BASE_LOG_DIR"
    sudo chmod 755 "$BASE_MIRROR_DIR"
    
    log_info "Directory structure created"
}

build_base_image() {
    log_info "Building base container image"
    
    local base_image="mirror-sync-base:latest"
    local base_context="$PROJECT_ROOT/base"
    
    if [[ ! -d "$base_context" ]]; then
        log_error "Base container context not found: $base_context"
        return 1
    fi
    
    if ! build_container_image "$base_image" "$base_context" "$BASE_LOG_DIR/base-build.log"; then
        log_error "Failed to build base image"
        return 1
    fi
    
    log_info "Base container image built successfully"
}

install_systemd_services() {
    [[ "${SETUP_SYSTEMD:-true}" != "true" ]] && return 0
    
    log_info "Installing systemd services"
    
    local services=(
        "apt-mirror/debian-apt-mirror.service"
        "apt-mirror/debian-apt-mirror.timer"
        "apt-mirror/ubuntu-apt-mirror.service"
        "apt-mirror/ubuntu-apt-mirror.timer"
        "rocky/rocky-apt-mirror.service"
        "rocky/rocky-apt-mirror.timer"
    )
    
    for service_file in "${services[@]}"; do
        local src="$PROJECT_ROOT/$service_file"
        local dst="/etc/systemd/system/$(basename "$service_file")"
        
        if [[ -f "$src" ]]; then
            log_info "Installing $(basename "$service_file")"
            sudo cp "$src" "$dst"
            sudo systemctl daemon-reload
        else
            log_warn "Service file not found: $src"
        fi
    done
    
    log_info "Systemd services installed (not enabled by default)"
    log_info "To enable: sudo systemctl enable debian-apt-mirror.timer"
    log_info "To start:  sudo systemctl start debian-apt-mirror.timer"
}

setup_monitoring() {
    log_info "Setting up monitoring"
    
    # Make monitoring script executable
    chmod +x "$PROJECT_ROOT/scripts/monitor-mirrors.sh"
    
    # Create monitoring cron job if requested
    if [[ "${SETUP_MONITORING_CRON:-true}" == "true" ]]; then
        local cron_entry="0 6 * * * $PROJECT_ROOT/scripts/monitor-mirrors.sh report"
        local existing_cron
        existing_cron=$(crontab -l 2>/dev/null || echo "")
        
        if ! echo "$existing_cron" | grep -q "monitor-mirrors.sh"; then
            (echo "$existing_cron"; echo "$cron_entry") | crontab -
            log_info "Added daily monitoring cron job (6 AM)"
        else
            log_info "Monitoring cron job already exists"
        fi
    fi
}

create_local_config_template() {
    log_info "Creating local configuration template"
    
    local local_config="$PROJECT_ROOT/config/local.conf"
    
    if [[ ! -f "$local_config" ]]; then
        cat > "$local_config" <<'EOF'
# Local configuration overrides for mirror-sync
# Copy values from mirror-sync.conf and customize as needed

# Example customizations:
# DEBIAN_SUITES="bookworm trixie"
# UBUNTU_VERSIONS="22.04 24.04"
# ROCKY_VERSIONS="9 10"
# DEFAULT_THREADS="10"
# ENABLE_NOTIFICATIONS="true"
# NOTIFICATION_EMAIL="admin@example.com"
EOF
        log_info "Local config template created: $local_config"
        log_info "Edit this file to customize your mirror configuration"
    else
        log_info "Local config already exists: $local_config"
    fi
}

# ========== Main Setup ==========
main() {
    local setup_type="${1:-all}"
    
    log_info "Starting mirror-sync setup (type: $setup_type)"
    
    case "$setup_type" in
        "prereq"|"prerequisites")
            check_prerequisites
            ;;
        "dirs"|"directories")  
            create_directories
            ;;
        "base"|"base-image")
            build_base_image
            ;;
        "systemd"|"services")
            install_systemd_services
            ;;
        "monitoring")
            setup_monitoring
            ;;
        "config")
            create_local_config_template
            ;;
        "all")
            check_prerequisites
            create_directories
            create_local_config_template
            build_base_image
            install_systemd_services
            setup_monitoring
            log_info "Setup completed successfully!"
            log_info ""
            log_info "Next steps:"
            log_info "1. Edit $PROJECT_ROOT/config/local.conf for custom settings"
            log_info "2. Enable desired services: sudo systemctl enable <service>.timer"
            log_info "3. Start services: sudo systemctl start <service>.timer"
            log_info "4. Monitor with: $PROJECT_ROOT/scripts/monitor-mirrors.sh check"
            ;;
        *)
            log_error "Usage: $0 {prereq|dirs|base|systemd|monitoring|config|all}"
            log_error "  prereq    - Check prerequisites only"
            log_error "  dirs      - Create directory structure"  
            log_error "  base      - Build base container image"
            log_error "  systemd   - Install systemd services"
            log_error "  monitoring - Set up monitoring"
            log_error "  config    - Create local config template"
            log_error "  all       - Run complete setup"
            exit 1
            ;;
    esac
    
    log_info "Setup operation '$setup_type' completed"
}

# Run main function
main "$@"