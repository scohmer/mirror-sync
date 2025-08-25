#!/usr/bin/env bash
# Consolidated debug menu for mirror-sync troubleshooting

set -euo pipefail

# Colors for output - check if terminal supports colors
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1 && [[ $(tput colors) -ge 8 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
    USE_COLORS=true
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
    USE_COLORS=false
fi

# Load configuration and common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

source "$PROJECT_ROOT/lib/common.sh"
load_config 2>/dev/null || true

# Helper function to print with colors
print_color() {
    local color="$1"
    local text="$2"
    if [[ "$USE_COLORS" == "true" ]]; then
        printf "${color}%s${NC}" "$text"
    else
        printf "%s" "$text"
    fi
}

print_header() {
    print_color "$BLUE" "=="================================
    echo
    print_color "$BLUE" "  Mirror Sync Debug Menu"
    echo
    print_color "$BLUE" "=="================================
    echo
    echo "Date: $(date)"
    echo "User: $(whoami)"
    echo "PWD: $(pwd)"
    echo "PROJECT_ROOT: ${PROJECT_ROOT:-NOT_SET}"
    echo
}

print_menu() {
    print_color "$YELLOW" "Available Debug Options:"
    echo
    echo
    echo -n "  "
    print_color "$GREEN" "Framework Tests:"
    echo
    echo "    1) Basic framework test (files, config, library loading)"
    echo "    2) Configuration loading test"
    echo "    3) Container runtime test"
    echo "    4) Network connectivity test"
    echo
    echo -n "  "
    print_color "$GREEN" "Function Tests:"
    echo
    echo "    5) Lock mechanism test"
    echo "    6) Disk space check test"
    echo "    7) Logging system test"
    echo "    8) Container image build test"
    echo
    echo -n "  "
    print_color "$GREEN" "Integration Tests:"
    echo
    echo "    9) Debian sync step-by-step test"
    echo "   10) Ubuntu sync step-by-step test"
    echo "   11) Rocky sync step-by-step test"
    echo
    echo -n "  "
    print_color "$GREEN" "System Information:"
    echo
    echo "   12) System status report"
    echo "   13) Container status"
    echo "   14) Mirror directory status"
    echo "   15) Log file analysis"
    echo
    echo -n "  "
    print_color "$GREEN" "Utilities:"
    echo
    echo "   16) Clean up test locks"
    echo "   17) Run full health check"
    echo
    echo "    0) Exit"
    echo
}

run_framework_test() {
    print_color "$BLUE" "=== Basic Framework Test ==="
    echo
    
    echo "Checking file existence..."
    local files_to_check=(
        "lib/common.sh"
        "config/mirror-sync.conf"
        "apt-mirror/debian-build-and-sync.sh"
        "apt-mirror/ubuntu-build-and-sync.sh"
        "rocky/rocky-build-and-sync.sh"
    )
    
    for file in "${files_to_check[@]}"; do
        if [[ -f "$file" ]]; then
            echo -n "  "
            print_color "$GREEN" "✓"
            echo " $file exists"
        else
            echo -n "  "
            print_color "$RED" "✗"
            echo " $file missing"
        fi
    done
    
    echo
    echo "Testing library loading..."
    if source lib/common.sh 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} lib/common.sh loaded successfully"
        
        if load_config 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Configuration loaded successfully"
            echo "    PROJECT_ROOT: ${PROJECT_ROOT:-NOT_SET}"
            echo "    BASE_LOG_DIR: ${BASE_LOG_DIR:-NOT_SET}"
        else
            echo -e "  ${RED}✗${NC} Configuration loading failed"
        fi
        
        if log_info "Test log message" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Logging functions work"
        else
            echo -e "  ${RED}✗${NC} Logging functions failed"
        fi
    else
        echo -e "  ${RED}✗${NC} Failed to load lib/common.sh"
    fi
}

run_config_test() {
    echo -e "${BLUE}=== Configuration Loading Test ===${NC}"
    
    local default_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/mirror-sync.conf"
    echo "Default config path: $default_config"
    
    if [[ -f "$default_config" ]]; then
        echo -e "${GREEN}✓${NC} Default config file exists"
        echo "File size: $(wc -l < "$default_config") lines"
        
        if source "$default_config" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Config file sources successfully"
            echo "Sample variables:"
            echo "  DEBIAN_TARGET: ${DEBIAN_TARGET:-NOT_SET}"
            echo "  UBUNTU_TARGET: ${UBUNTU_TARGET:-NOT_SET}"
            echo "  ROCKY_TARGET: ${ROCKY_TARGET:-NOT_SET}"
        else
            echo -e "${RED}✗${NC} Config file has syntax errors"
        fi
    else
        echo -e "${RED}✗${NC} Default config file missing"
        echo "Run: sudo ./scripts/setup-mirrors.sh config"
    fi
}

run_container_test() {
    echo -e "${BLUE}=== Container Runtime Test ===${NC}"
    
    if command -v podman >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} podman available: $(podman --version)"
        
        if podman info >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} podman info command works"
        else
            echo -e "${RED}✗${NC} podman info command failed"
        fi
        
        echo "Current images:"
        podman images | head -5
        
    elif command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} docker available: $(docker --version)"
        
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} docker info command works"
        else
            echo -e "${RED}✗${NC} docker info command failed"
        fi
        
    else
        echo -e "${RED}✗${NC} No container runtime (podman/docker) found"
    fi
}

run_network_test() {
    echo -e "${BLUE}=== Network Connectivity Test ===${NC}"
    
    echo "Testing general connectivity..."
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Internet connectivity confirmed"
    else
        echo -e "${RED}✗${NC} No internet connectivity"
    fi
    
    echo "Testing repository connectivity..."
    local repos=(
        "http://deb.debian.org/debian"
        "http://archive.ubuntu.com/ubuntu"
        "https://dl.rockylinux.org/pub/rocky"
    )
    
    for repo in "${repos[@]}"; do
        if curl -f -s --connect-timeout 10 "$repo" >/dev/null; then
            echo -e "${GREEN}✓${NC} $repo reachable"
        else
            echo -e "${RED}✗${NC} $repo not reachable"
        fi
    done
}

run_lock_test() {
    echo -e "${BLUE}=== Lock Mechanism Test ===${NC}"
    
    local test_lock="/var/lock/debug-test.lock"
    
    echo "Testing lock creation..."
    if lock_or_exit "$test_lock" "debug-test" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Lock acquired successfully"
        
        echo "Cleaning up test lock..."
        rm -f "$test_lock"
        echo -e "${GREEN}✓${NC} Lock cleaned up"
    else
        echo -e "${RED}✗${NC} Lock test failed"
    fi
}

run_disk_test() {
    echo -e "${BLUE}=== Disk Space Check Test ===${NC}"
    
    local test_paths=(
        "${DEBIAN_TARGET:-/srv/mirrors/debian}"
        "${UBUNTU_TARGET:-/srv/mirrors/ubuntu}"
        "${ROCKY_TARGET:-/srv/mirrors/rocky}"
    )
    
    for path in "${test_paths[@]}"; do
        echo "Testing path: $path"
        if check_disk_space "$path" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Disk space check passed for $path"
        else
            echo -e "${YELLOW}⚠${NC} Disk space warning for $path"
        fi
    done
}

run_integration_test() {
    local distribution="$1"
    echo -e "${BLUE}=== $distribution Integration Test ===${NC}"
    
    case "$distribution" in
        "Debian")
            local image="debian-mirror:latest"
            local ctx="./apt-mirror/deb.debian.org"
            local target="${DEBIAN_TARGET:-/srv/mirrors/debian}"
            local lock_file="/var/lock/debian-debug.lock"
            ;;
        "Ubuntu")
            local image="ubuntu-mirror:latest"
            local ctx="./apt-mirror/archive.ubuntu.com"
            local target="${UBUNTU_TARGET:-/srv/mirrors/ubuntu}"
            local lock_file="/var/lock/ubuntu-debug.lock"
            ;;
        "Rocky")
            local image="rocky-mirror:latest"
            local ctx="./rocky/dl.rockylinux.org"
            local target="${ROCKY_TARGET:-/srv/mirrors/rocky}"
            local lock_file="/var/lock/rocky-debug.lock"
            ;;
    esac
    
    echo "Testing each step for $distribution..."
    
    echo "1. Lock test..."
    if lock_or_exit "$lock_file" "${distribution,,}-debug" 2>/dev/null; then
        echo -e "   ${GREEN}✓${NC} Lock acquired"
    else
        echo -e "   ${RED}✗${NC} Lock failed"
        return 1
    fi
    
    echo "2. Network test..."
    if wait_for_network 2>/dev/null; then
        echo -e "   ${GREEN}✓${NC} Network confirmed"
    else
        echo -e "   ${RED}✗${NC} Network failed"
    fi
    
    echo "3. Disk space test..."
    if check_disk_space "$target" 2>/dev/null; then
        echo -e "   ${GREEN}✓${NC} Disk space OK"
    else
        echo -e "   ${YELLOW}⚠${NC} Disk space warning"
    fi
    
    echo "4. Container context test..."
    if [[ -d "$ctx" ]]; then
        echo -e "   ${GREEN}✓${NC} Context directory exists: $ctx"
    else
        echo -e "   ${RED}✗${NC} Context directory missing: $ctx"
    fi
    
    echo "5. Container build test (dry run)..."
    local runtime
    runtime="$(get_container_runtime)"
    echo -e "   ${GREEN}✓${NC} Would use runtime: $runtime"
    echo -e "   ${GREEN}✓${NC} Would build image: $image"
    
    rm -f "$lock_file"
}

run_system_status() {
    echo -e "${BLUE}=== System Status Report ===${NC}"
    
    echo "System Information:"
    echo "  OS: $(uname -s -r)"
    echo "  User: $(whoami)"
    echo "  PWD: $(pwd)"
    echo "  Date: $(date)"
    echo
    
    echo "Storage Information:"
    echo "  Available space:"
    df -h / | tail -n +2
    echo
    
    echo "Memory Information:"
    free -h
    echo
    
    echo "Container Runtime:"
    if command -v podman >/dev/null 2>&1; then
        echo "  Podman: $(podman --version)"
        echo "  Running containers: $(podman ps -q | wc -l)"
    elif command -v docker >/dev/null 2>&1; then
        echo "  Docker: $(docker --version)"
        echo "  Running containers: $(docker ps -q | wc -l)"
    else
        echo "  No container runtime found"
    fi
}

run_container_status() {
    echo -e "${BLUE}=== Container Status ===${NC}"
    
    local runtime
    if command -v podman >/dev/null 2>&1; then
        runtime="podman"
    elif command -v docker >/dev/null 2>&1; then
        runtime="docker"
    else
        echo -e "${RED}✗${NC} No container runtime found"
        return 1
    fi
    
    echo "Running containers:"
    if ! "$runtime" ps; then
        echo "  No running containers"
    fi
    echo
    
    echo "All containers:"
    if ! "$runtime" ps -a; then
        echo "  No containers found"
    fi
    echo
    
    echo "Images:"
    "$runtime" images | head -10
}

run_mirror_status() {
    echo -e "${BLUE}=== Mirror Directory Status ===${NC}"
    
    local base_dir="${BASE_MIRROR_DIR:-/srv/mirrors}"
    echo "Base mirror directory: $base_dir"
    
    if [[ -d "$base_dir" ]]; then
        echo -e "${GREEN}✓${NC} Base directory exists"
        echo
        
        for subdir in debian ubuntu rocky; do
            local mirror_dir="$base_dir/$subdir"
            echo "$subdir mirror:"
            if [[ -d "$mirror_dir" ]]; then
                local size=$(du -sh "$mirror_dir" 2>/dev/null | cut -f1)
                local files=$(find "$mirror_dir" -type f 2>/dev/null | wc -l)
                local latest=$(find "$mirror_dir" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
                
                echo -e "  ${GREEN}✓${NC} Directory exists: $mirror_dir"
                echo "    Size: $size"
                echo "    Files: $files"
                if [[ -n "$latest" ]]; then
                    echo "    Latest file: $(basename "$latest")"
                    echo "    Last modified: $(stat -c %y "$latest" 2>/dev/null)"
                fi
            else
                echo -e "  ${YELLOW}-${NC} Directory does not exist: $mirror_dir"
            fi
            echo
        done
    else
        echo -e "${RED}✗${NC} Base directory does not exist: $base_dir"
        echo "Run: sudo ./scripts/setup-mirrors.sh dirs"
    fi
}

run_log_analysis() {
    echo -e "${BLUE}=== Log File Analysis ===${NC}"
    
    local log_base="${BASE_LOG_DIR:-/opt/mirror-sync/logs}"
    echo "Log directory: $log_base"
    
    if [[ -d "$log_base" ]]; then
        echo -e "${GREEN}✓${NC} Log directory exists"
        echo
        
        for service in debian ubuntu rocky; do
            local service_log_dir="$log_base/$service"
            echo "$service logs:"
            if [[ -d "$service_log_dir" ]]; then
                echo -e "  ${GREEN}✓${NC} Log directory exists: $service_log_dir"
                
                for log_type in build run; do
                    local log_file="$service_log_dir/${log_type}.log"
                    if [[ -f "$log_file" ]]; then
                        local size=$(du -sh "$log_file" | cut -f1)
                        local lines=$(wc -l < "$log_file")
                        local modified=$(stat -c %y "$log_file")
                        
                        echo "    ${log_type}.log: $size, $lines lines, modified $modified"
                        echo "    Last 3 lines:"
                        tail -3 "$log_file" | sed 's/^/      /'
                    else
                        echo -e "    ${YELLOW}-${NC} No ${log_type}.log file"
                    fi
                done
            else
                echo -e "  ${YELLOW}-${NC} No log directory: $service_log_dir"
            fi
            echo
        done
    else
        echo -e "${RED}✗${NC} Log directory does not exist: $log_base"
        echo "Run: sudo ./scripts/setup-mirrors.sh dirs"
    fi
}

cleanup_locks() {
    echo -e "${BLUE}=== Cleaning Up Test Locks ===${NC}"
    
    local lock_files=(
        "/var/lock/debug-test.lock"
        "/var/lock/debian-debug.lock"
        "/var/lock/ubuntu-debug.lock"
        "/var/lock/rocky-debug.lock"
        "/var/lock/debian-mirror-sync.lock"
        "/var/lock/ubuntu-mirror-sync.lock"
        "/var/lock/rocky-mirror-sync.lock"
    )
    
    for lock_file in "${lock_files[@]}"; do
        if [[ -f "$lock_file" ]]; then
            rm -f "$lock_file"
            echo -e "${GREEN}✓${NC} Removed $lock_file"
        fi
    done
    
    echo "Lock cleanup completed"
}

run_health_check() {
    echo -e "${BLUE}=== Full Health Check ===${NC}"
    
    echo "Running comprehensive system check..."
    echo
    
    run_framework_test
    echo
    run_config_test
    echo
    run_container_test
    echo
    run_network_test
    echo
    
    echo -e "${GREEN}Health check completed${NC}"
}

# Main menu loop
main() {
    while true; do
        clear
        print_header
        print_menu
        
        read -p "Enter your choice (0-17): " choice
        echo
        
        case $choice in
            1) run_framework_test ;;
            2) run_config_test ;;
            3) run_container_test ;;
            4) run_network_test ;;
            5) run_lock_test ;;
            6) run_disk_test ;;
            7) setup_logging "/tmp/debug-log-test" "debug" && echo "Logging test completed" ;;
            8) run_container_test ;;
            9) run_integration_test "Debian" ;;
            10) run_integration_test "Ubuntu" ;;
            11) run_integration_test "Rocky" ;;
            12) run_system_status ;;
            13) run_container_status ;;
            14) run_mirror_status ;;
            15) run_log_analysis ;;
            16) cleanup_locks ;;
            17) run_health_check ;;
            0) 
                echo "Exiting debug menu..."
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main menu
main "$@"