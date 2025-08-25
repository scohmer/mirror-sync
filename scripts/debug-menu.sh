#!/usr/bin/env bash
# Consolidated debug menu for mirror-sync troubleshooting - Simple version

set -euo pipefail

# Simple color handling - disable if not supported
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    BOLD=$(tput bold)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    RESET=$(tput sgr0)
else
    BOLD=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    RESET=""
fi

# Load configuration and common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

source "$PROJECT_ROOT/lib/common.sh"
load_config 2>/dev/null || true

print_header() {
    echo "${BLUE}${BOLD}=================================="
    echo "  Mirror Sync Debug Menu"
    echo "==================================${RESET}"
    echo "Date: $(date)"
    echo "User: $(whoami)"
    echo "PWD: $(pwd)"
    echo "PROJECT_ROOT: ${PROJECT_ROOT:-NOT_SET}"
    echo
}

print_menu() {
    echo "${YELLOW}${BOLD}Available Debug Options:${RESET}"
    echo
    echo "  ${GREEN}Framework Tests:${RESET}"
    echo "    1) Basic framework test (files, config, library loading)"
    echo "    2) Configuration loading test"
    echo "    3) Container runtime test"
    echo "    4) Network connectivity test"
    echo
    echo "  ${GREEN}Function Tests:${RESET}"
    echo "    5) Lock mechanism test"
    echo "    6) Disk space check test"
    echo "    7) Logging system test"
    echo "    8) Container image build test"
    echo
    echo "  ${GREEN}Integration Tests:${RESET}"
    echo "    9) Debian sync step-by-step test"
    echo "   10) Ubuntu sync step-by-step test"
    echo "   11) Rocky sync step-by-step test"
    echo
    echo "  ${GREEN}System Information:${RESET}"
    echo "   12) System status report"
    echo "   13) Container status"
    echo "   14) Mirror directory status"
    echo "   15) Log file analysis"
    echo
    echo "  ${GREEN}Utilities:${RESET}"
    echo "   16) Clean up test locks"
    echo "   17) Run full health check"
    echo
    echo "    0) Exit"
    echo
}

run_framework_test() {
    echo "${BLUE}${BOLD}=== Basic Framework Test ===${RESET}"
    
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
            echo "  ${GREEN}✓${RESET} $file exists"
        else
            echo "  ${RED}✗${RESET} $file missing"
        fi
    done
    
    echo
    echo "Testing library loading..."
    if source lib/common.sh 2>/dev/null; then
        echo "  ${GREEN}✓${RESET} lib/common.sh loaded successfully"
        
        if load_config 2>/dev/null; then
            echo "  ${GREEN}✓${RESET} Configuration loaded successfully"
            echo "    PROJECT_ROOT: ${PROJECT_ROOT:-NOT_SET}"
            echo "    BASE_LOG_DIR: ${BASE_LOG_DIR:-NOT_SET}"
        else
            echo "  ${RED}✗${RESET} Configuration loading failed"
        fi
        
        if log_info "Test log message" 2>/dev/null; then
            echo "  ${GREEN}✓${RESET} Logging functions work"
        else
            echo "  ${RED}✗${RESET} Logging functions failed"
        fi
    else
        echo "  ${RED}✗${RESET} Failed to load lib/common.sh"
    fi
}

run_config_test() {
    echo "${BLUE}${BOLD}=== Configuration Loading Test ===${RESET}"
    
    local default_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/mirror-sync.conf"
    echo "Default config path: $default_config"
    
    if [[ -f "$default_config" ]]; then
        echo "${GREEN}✓${RESET} Default config file exists"
        echo "File size: $(wc -l < "$default_config") lines"
        
        if source "$default_config" 2>/dev/null; then
            echo "${GREEN}✓${RESET} Config file sources successfully"
            echo "Sample variables:"
            echo "  DEBIAN_TARGET: ${DEBIAN_TARGET:-NOT_SET}"
            echo "  UBUNTU_TARGET: ${UBUNTU_TARGET:-NOT_SET}"
            echo "  ROCKY_TARGET: ${ROCKY_TARGET:-NOT_SET}"
        else
            echo "${RED}✗${RESET} Config file has syntax errors"
        fi
    else
        echo "${RED}✗${RESET} Default config file missing"
        echo "Run: sudo ./scripts/setup-mirrors.sh config"
    fi
}

run_quick_health_check() {
    echo "${BLUE}${BOLD}=== Quick Health Check ===${RESET}"
    
    echo "Framework:"
    if source lib/common.sh 2>/dev/null && load_config 2>/dev/null; then
        echo "  ${GREEN}✓${RESET} Framework operational"
    else
        echo "  ${RED}✗${RESET} Framework issues detected"
    fi
    
    echo "Container Runtime:"
    if command -v podman >/dev/null 2>&1; then
        echo "  ${GREEN}✓${RESET} podman available"
    elif command -v docker >/dev/null 2>&1; then
        echo "  ${GREEN}✓${RESET} docker available"  
    else
        echo "  ${RED}✗${RESET} No container runtime found"
    fi
    
    echo "Network:"
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        echo "  ${GREEN}✓${RESET} Internet connectivity confirmed"
    else
        echo "  ${RED}✗${RESET} No internet connectivity"
    fi
    
    echo "Storage:"
    local usage=$(df . | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ "$usage" -lt 90 ]]; then
        echo "  ${GREEN}✓${RESET} Disk usage: ${usage}%"
    else
        echo "  ${YELLOW}⚠${RESET} High disk usage: ${usage}%"
    fi
}

# Main menu loop with simplified options
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
            3) echo "Container runtime: $(command -v podman || command -v docker || echo 'Not found')" ;;
            4) ping -c 1 8.8.8.8 && echo "Network OK" || echo "Network failed" ;;
            5) echo "Lock test - not implemented in simple version" ;;
            6) echo "Disk test - not implemented in simple version" ;;
            7) echo "Logging test - not implemented in simple version" ;;
            8) echo "Container build test - not implemented in simple version" ;;
            9) echo "Debian integration test - not implemented in simple version" ;;
            10) echo "Ubuntu integration test - not implemented in simple version" ;;
            11) echo "Rocky integration test - not implemented in simple version" ;;
            12) 
                echo "System: $(uname -a)"
                echo "Storage: $(df -h . | tail -1)"
                echo "Memory: $(free -h | head -2 | tail -1)"
                ;;
            13) 
                if command -v podman >/dev/null 2>&1; then
                    podman ps -a
                elif command -v docker >/dev/null 2>&1; then
                    docker ps -a
                else
                    echo "No container runtime found"
                fi
                ;;
            14) 
                echo "Mirror directories:"
                ls -la /srv/mirrors/ 2>/dev/null || echo "No mirror directories found"
                ;;
            15) 
                echo "Recent logs:"
                find /opt/mirror-sync/logs -name "*.log" -mtime -1 2>/dev/null | head -5
                ;;
            16) 
                echo "Cleaning up locks..."
                rm -f /var/lock/*mirror*.lock
                echo "Done"
                ;;
            17) run_quick_health_check ;;
            0) 
                echo "Exiting debug menu..."
                exit 0
                ;;
            *)
                echo "${RED}Invalid choice. Please try again.${RESET}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main menu
main "$@"