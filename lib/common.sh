#!/usr/bin/env bash
# Common utilities for mirror-sync operations

set -euo pipefail

# Initialize common variables to prevent unbound variable errors
export PROJECT_ROOT="${PROJECT_ROOT:-}"
export BASE_LOG_DIR="${BASE_LOG_DIR:-}"
export LOCK_FILE="${LOCK_FILE:-}"

# ========== Configuration Loading ==========
load_config() {
    local config_file="${1:-}"
    local default_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/mirror-sync.conf"
    
    # Load default config if it exists
    [[ -f "$default_config" ]] && source "$default_config"
    
    # Load custom config if provided
    [[ -n "$config_file" && -f "$config_file" ]] && source "$config_file"
    
    # Load local overrides if they exist
    local local_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/local.conf"
    [[ -f "$local_config" ]] && source "$local_config"
    
    # Always return success
    return 0
}

# ========== Logging Functions ==========
log() {
    printf '[%(%Y-%m-%d %H:%M:%S)T] %s\n' -1 "$*" >&2
}

log_info() {
    log "[INFO] $*"
}

log_warn() {
    log "[WARN] $*"
}

log_error() {
    log "[ERROR] $*"
}

log_debug() {
    [[ "${DEBUG:-}" == "true" ]] && log "[DEBUG] $*"
    return 0
}

# ========== Container Management ==========
get_container_runtime() {
    local runtime="${CONTAINER_RUNTIME:-podman}"
    if ! command -v "$runtime" >/dev/null 2>&1; then
        log_warn "$runtime not found, falling back to docker"
        runtime="docker"
        if ! command -v "$runtime" >/dev/null 2>&1; then
            log_error "No container runtime found (tried podman and docker)"
            exit 1
        fi
    fi
    echo "$runtime"
}

build_container_image() {
    local image_name="$1"
    local context_dir="$2"
    local log_file="$3"
    local runtime
    runtime="$(get_container_runtime)"
    
    log_info "Building container image: $image_name"
    log_debug "Context: $context_dir, Runtime: $runtime"
    
    if ! "$runtime" build -t "$image_name" "$context_dir" >"$log_file" 2>&1; then
        log_error "Container build failed. See: $log_file"
        return 1
    fi
    
    log_info "Built $image_name successfully"
}

run_container() {
    local image_name="$1"
    local container_name="$2"
    local log_file="$3"
    shift 3
    local runtime
    runtime="$(get_container_runtime)"
    
    # Build resource limits
    local resource_args=()
    [[ -n "${DEFAULT_MEMORY_LIMIT:-}" ]] && resource_args+=("--memory=${DEFAULT_MEMORY_LIMIT}")
    [[ -n "${DEFAULT_CPU_LIMIT:-}" ]] && resource_args+=("--cpus=${DEFAULT_CPU_LIMIT}")
    
    log_info "Running container: $container_name"
    log_debug "Image: $image_name, Runtime: $runtime"
    
    if ! "$runtime" run --rm --name "$container_name" \
        "${resource_args[@]}" \
        "$@" \
        "$image_name" >"$log_file" 2>&1; then
        log_error "Container execution failed. See: $log_file"
        return 1
    fi
    
    log_info "Container $container_name completed successfully"
}

cleanup_old_images() {
    local image_pattern="$1"
    local keep_count="${KEEP_IMAGE_VERSIONS:-3}"
    local runtime
    runtime="$(get_container_runtime)"
    
    log_info "Cleaning up old images matching: $image_pattern"
    
    # Get image IDs, skip the most recent ones
    local old_images
    old_images=$("$runtime" images --format "{{.ID}}" --filter "reference=$image_pattern" | tail -n +$((keep_count + 1)))
    
    if [[ -n "$old_images" ]]; then
        echo "$old_images" | xargs -r "$runtime" rmi
        log_info "Cleaned up $(echo "$old_images" | wc -l) old images"
    else
        log_debug "No old images to clean up"
    fi
}

# ========== Filesystem Operations ==========
prepare_target_directory() {
    local target_dir="$1"
    local owner="${2:-root:root}"
    
    log_info "Preparing target directory: $target_dir"
    sudo mkdir -p "$target_dir"
    sudo chown "$owner" "$target_dir"
    
    # SELinux context if needed
    if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce)" != "Disabled" ]]; then
        sudo chcon -Rt container_file_t "$target_dir" || true
    fi
}

check_disk_space() {
    local path="$1"
    local threshold="${DISK_USAGE_THRESHOLD:-85}"
    
    # If path doesn't exist, check parent directory
    local check_path="$path"
    while [[ ! -d "$check_path" && "$check_path" != "/" ]]; do
        check_path="$(dirname "$check_path")"
    done
    
    local usage
    usage=$(df "$check_path" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ "$usage" -gt "$threshold" ]]; then
        log_warn "Disk usage at $check_path is ${usage}% (threshold: ${threshold}%)"
        send_notification "High disk usage" "Disk usage at $check_path is ${usage}%"
        return 1
    fi
    
    log_debug "Disk usage at $check_path: ${usage}%"
    return 0
}

# ========== Log Management ==========
setup_logging() {
    local log_dir="$1"
    local service_name="$2"
    
    mkdir -p "$log_dir"
    
    # Set up log rotation if logrotate is available
    if command -v logrotate >/dev/null 2>&1; then
        local logrotate_conf="/etc/logrotate.d/mirror-sync-$service_name"
        sudo tee "$logrotate_conf" >/dev/null <<EOF
$log_dir/*.log {
    daily
    rotate ${LOG_RETENTION_DAYS:-30}
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
    fi
    
    echo "$log_dir"
}

cleanup_old_logs() {
    local log_dir="$1"
    local retention_days="${LOG_RETENTION_DAYS:-30}"
    
    log_info "Cleaning up logs older than $retention_days days in $log_dir"
    find "$log_dir" -name "*.log" -type f -mtime "+$retention_days" -delete 2>/dev/null || true
}

# ========== Notification System ==========
send_notification() {
    local title="$1"
    local message="$2"
    
    [[ "${ENABLE_NOTIFICATIONS:-false}" != "true" ]] && return 0
    
    # Email notification
    if [[ -n "${NOTIFICATION_EMAIL:-}" ]] && command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "Mirror Sync: $title" "$NOTIFICATION_EMAIL"
    fi
    
    # Slack notification
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]] && command -v curl >/dev/null 2>&1; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"Mirror Sync: $title\\n$message\"}" \
            "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || true
    fi
    
    log_info "Notification sent: $title"
}

# ========== Health Checks ==========
run_health_checks() {
    local mirror_dir="$1"
    local service_name="$2"
    
    log_info "Running health checks for $service_name"
    
    # Check if mirror directory exists and has content
    if [[ ! -d "$mirror_dir" ]]; then
        log_error "Mirror directory does not exist: $mirror_dir"
        return 1
    fi
    
    # Check disk space
    if ! check_disk_space "$mirror_dir"; then
        log_warn "Disk space check failed"
    fi
    
    # Check if mirror has recent activity
    local latest_file
    latest_file=$(find "$mirror_dir" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    if [[ -n "$latest_file" ]]; then
        local file_age_hours
        file_age_hours=$(( ($(date +%s) - $(stat -c %Y "$latest_file")) / 3600 ))
        log_debug "Latest file modified $file_age_hours hours ago: $latest_file"
        
        if [[ "$file_age_hours" -gt 48 ]]; then
            log_warn "Mirror appears stale - no updates in $file_age_hours hours"
        fi
    fi
    
    log_info "Health checks completed for $service_name"
}

# ========== Utility Functions ==========
wait_for_network() {
    local timeout="${1:-60}"
    local count=0
    
    log_info "Waiting for network connectivity..."
    
    while ! ping -c 1 8.8.8.8 >/dev/null 2>&1; do
        if [[ "$count" -gt "$timeout" ]]; then
            log_error "Network connectivity timeout after ${timeout}s"
            return 1
        fi
        sleep 1
        ((count++))
    done
    
    log_info "Network connectivity confirmed"
}

lock_or_exit() {
    local lock_file="$1"
    local service_name="$2"
    
    exec 200>"$lock_file"
    if ! flock -n 200; then
        log_warn "$service_name is already running (lock: $lock_file)"
        exit 0
    fi
    
    # Clean up lock on exit - use hard-coded path to avoid variable scope issues
    trap "rm -f '$lock_file'" EXIT
}