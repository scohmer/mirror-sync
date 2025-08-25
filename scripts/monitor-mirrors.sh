#!/usr/bin/env bash
# Monitoring script for all mirror sync operations

set -euo pipefail

# Load configuration and common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=../lib/common.sh
source "$PROJECT_ROOT/lib/common.sh"
load_config

# ========== Monitoring Functions ==========
check_mirror_health() {
    local mirror_type="$1"
    local mirror_path="$2"
    local status="UNKNOWN"
    
    log_info "Checking $mirror_type mirror health at $mirror_path"
    
    if [[ ! -d "$mirror_path" ]]; then
        log_error "$mirror_type mirror directory not found: $mirror_path"
        echo "CRITICAL"
        return
    fi
    
    # Check disk usage
    local disk_usage
    disk_usage=$(df "$mirror_path" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ "$disk_usage" -gt "${DISK_USAGE_THRESHOLD:-85}" ]]; then
        log_warn "$mirror_type mirror disk usage: ${disk_usage}%"
        status="WARNING"
    fi
    
    # Check for recent activity (files modified in last 48 hours)
    local recent_files
    recent_files=$(find "$mirror_path" -type f -mtime -2 2>/dev/null | wc -l)
    
    if [[ "$recent_files" -eq 0 ]]; then
        log_warn "$mirror_type mirror appears stale (no recent updates)"
        status="WARNING"
    else
        log_info "$mirror_type mirror has $recent_files recently updated files"
        [[ "$status" == "UNKNOWN" ]] && status="OK"
    fi
    
    # Check mirror size
    local mirror_size
    mirror_size=$(du -sh "$mirror_path" 2>/dev/null | cut -f1)
    log_info "$mirror_type mirror size: $mirror_size"
    
    echo "$status"
}

check_container_status() {
    local runtime
    runtime="$(get_container_runtime)"
    
    log_info "Checking container status"
    
    # Check if any mirror containers are running
    local running_containers
    running_containers=$("$runtime" ps --filter "name=*mirror*" --format "{{.Names}}" | wc -l)
    
    if [[ "$running_containers" -gt 0 ]]; then
        log_info "$running_containers mirror containers currently running"
        "$runtime" ps --filter "name=*mirror*" --format "table {{.Names}}\t{{.Status}}\t{{.Command}}"
    else
        log_info "No mirror containers currently running"
    fi
    
    # Check for failed containers in last 24 hours
    local failed_containers
    failed_containers=$("$runtime" ps -a --filter "name=*mirror*" --filter "status=exited" \
        --format "{{.Names}}\t{{.Status}}" | grep -E "Exited \([1-9]" | wc -l)
    
    if [[ "$failed_containers" -gt 0 ]]; then
        log_warn "$failed_containers mirror containers have failed recently"
        return 1
    fi
    
    return 0
}

check_systemd_services() {
    log_info "Checking systemd service status"
    
    local services=(
        "debian-apt-mirror.service"
        "ubuntu-apt-mirror.service"
        "rocky-apt-mirror.service"
    )
    
    local failed_services=0
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            local status
            status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            
            case "$status" in
                "active")
                    log_info "$service is active"
                    ;;
                "inactive"|"failed")
                    log_warn "$service is $status"
                    # Check when it last ran
                    local last_run
                    last_run=$(systemctl show "$service" -p ActiveEnterTimestamp --value 2>/dev/null || echo "unknown")
                    log_info "$service last active: $last_run"
                    ;;
                *)
                    log_error "$service status unknown: $status"
                    ((failed_services++))
                    ;;
            esac
        else
            log_debug "$service is not enabled, skipping"
        fi
    done
    
    return $failed_services
}

generate_report() {
    local debian_status ubuntu_status rocky_status
    
    log_info "Generating mirror status report"
    
    # Check each mirror type
    debian_status=$(check_mirror_health "Debian" "${DEBIAN_TARGET}")
    ubuntu_status=$(check_mirror_health "Ubuntu" "${UBUNTU_TARGET}")
    rocky_status=$(check_mirror_health "Rocky" "${ROCKY_TARGET}")
    
    # Generate summary report
    cat > "$BASE_LOG_DIR/mirror-status-report.txt" <<EOF
Mirror Sync Status Report
Generated: $(date)

=== Mirror Health Status ===
Debian Mirror: $debian_status
Ubuntu Mirror: $ubuntu_status
Rocky Mirror:  $rocky_status

=== Disk Usage ===
$(df -h "${DEBIAN_TARGET}" "${UBUNTU_TARGET}" "${ROCKY_TARGET}" 2>/dev/null || echo "Some paths not accessible")

=== System Load ===
$(uptime)
$(free -h)

=== Container Status ===
$(get_container_runtime) ps --filter "name=*mirror*" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

=== Recent Logs (Last 50 lines) ===
$(find "$BASE_LOG_DIR" -name "*.log" -type f -exec tail -10 {} \; 2>/dev/null | tail -50)
EOF

    log_info "Status report generated: $BASE_LOG_DIR/mirror-status-report.txt"
}

send_status_notifications() {
    local overall_status="OK"
    
    # Check if any critical issues exist
    if ! check_disk_space "${DEBIAN_TARGET}" || \
       ! check_disk_space "${UBUNTU_TARGET}" || \
       ! check_disk_space "${ROCKY_TARGET}"; then
        overall_status="CRITICAL"
    fi
    
    if ! check_container_status; then
        overall_status="WARNING"
    fi
    
    # Send notification if there are issues or if forced
    if [[ "$overall_status" != "OK" ]] || [[ "${FORCE_NOTIFICATION:-}" == "true" ]]; then
        local message="Mirror sync status: $overall_status"
        message="$message\n\nSee full report at: $BASE_LOG_DIR/mirror-status-report.txt"
        
        send_notification "Mirror Status: $overall_status" "$message"
    fi
    
    log_info "Overall mirror status: $overall_status"
}

# ========== Main Execution ==========
main() {
    local action="${1:-check}"
    
    # Setup logging
    setup_logging "$BASE_LOG_DIR" "monitor"
    
    case "$action" in
        "check"|"status")
            log_info "Running mirror health checks"
            check_mirror_health "Debian" "${DEBIAN_TARGET}"
            check_mirror_health "Ubuntu" "${UBUNTU_TARGET}"  
            check_mirror_health "Rocky" "${ROCKY_TARGET}"
            check_container_status
            check_systemd_services
            ;;
        "report")
            log_info "Generating comprehensive status report"
            generate_report
            send_status_notifications
            ;;
        "alert")
            log_info "Sending status notifications"
            FORCE_NOTIFICATION=true
            send_status_notifications
            ;;
        "cleanup")
            log_info "Running cleanup operations"
            cleanup_old_logs "$BASE_LOG_DIR"
            
            # Cleanup old containers if enabled
            if [[ "${AUTO_CLEANUP_OLD_IMAGES:-true}" == "true" ]]; then
                cleanup_old_images "debian-mirror"
                cleanup_old_images "ubuntu-mirror" 
                cleanup_old_images "rocky-mirror"
            fi
            ;;
        *)
            log_error "Usage: $0 {check|report|alert|cleanup}"
            log_error "  check  - Run basic health checks"
            log_error "  report - Generate full status report"
            log_error "  alert  - Send status notifications"
            log_error "  cleanup - Clean up old logs and images"
            exit 1
            ;;
    esac
    
    log_info "Monitor operation '$action' completed"
}

# Run main function
main "$@"