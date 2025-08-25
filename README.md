# Mirror Sync Project

A containerized Linux distribution mirror synchronization system with centralized configuration, monitoring, and automation.

## Overview

This project provides a modular, automated solution for synchronizing Linux distribution mirrors including **Debian**, **Ubuntu**, and **Rocky Linux**. It features centralized configuration management, comprehensive monitoring, resource management, and streamlined deployment.

### Supported Distributions

- **Debian** (bullseye, bookworm, trixie) - via `apt-mirror`
- **Ubuntu** (20.04, 22.04, 24.04, 25.04) - via `apt-mirror` 
- **Rocky Linux** (8, 9, 10) - via `dnf reposync`

## Architecture

The project follows a containerized approach with shared components:

1. **Shared Configuration** (`config/mirror-sync.conf`) - Centralized settings for all distributions
2. **Common Library** (`lib/common.sh`) - Shared functions for logging, container management, monitoring
3. **Base Container** (`base/Containerfile`) - Common base image for all mirrors
4. **Distribution-specific Containers** - Specialized containers with sync tools
5. **Build Scripts** - Automated container building and synchronization orchestration
6. **Systemd Integration** - Service units and timers for automated scheduling
7. **Monitoring System** - Health checks, notifications, and reporting

## Quick Start

### 1. Initial Setup

```bash
# Clone and enter the repository
cd mirror-sync

# Run complete setup
sudo ./scripts/setup-mirrors.sh all
```

### 2. Configuration

Edit local configuration:
```bash
sudo nano /opt/mirror-sync/config/local.conf
```

Example customizations:
```bash
# Mirror only specific versions
DEBIAN_SUITES="bookworm trixie"
UBUNTU_VERSIONS="22.04 24.04"
ROCKY_VERSIONS="9 10"

# Reduce resource usage
DEFAULT_THREADS="10"
DEBIAN_ARCHS="amd64"

# Enable notifications
ENABLE_NOTIFICATIONS="true"
NOTIFICATION_EMAIL="admin@example.com"
```

### 3. Enable and Start Services

```bash
# Enable timers for automated sync
sudo systemctl enable debian-apt-mirror.timer
sudo systemctl enable ubuntu-apt-mirror.timer
sudo systemctl enable rocky-apt-mirror.timer

# Start the timers
sudo systemctl start debian-apt-mirror.timer
sudo systemctl start ubuntu-apt-mirror.timer
sudo systemctl start rocky-apt-mirror.timer
```

### 4. Manual Sync (Optional)

```bash
# Run individual mirrors manually
sudo ./apt-mirror/debian-build-and-sync.sh
sudo ./apt-mirror/ubuntu-build-and-sync.sh
sudo ./rocky/rocky-build-and-sync.sh
```

## Configuration System

### Global Configuration (`config/mirror-sync.conf`)

- **Paths**: Mirror storage locations, log directories
- **Resources**: Memory/CPU limits, thread counts, timeouts
- **Distribution Settings**: Versions, architectures, components
- **Monitoring**: Disk thresholds, notifications
- **Cleanup**: Log retention, image cleanup policies

### Local Overrides (`config/local.conf`)

Override any setting from the global config without modifying the main file.

## Monitoring and Management

### Status Monitoring

```bash
# Check mirror health
./scripts/monitor-mirrors.sh check

# Generate comprehensive report
./scripts/monitor-mirrors.sh report

# Force send notifications
./scripts/monitor-mirrors.sh alert

# Clean up old logs and images
./scripts/monitor-mirrors.sh cleanup
```

### Logs

- **Build logs**: `$BASE_LOG_DIR/{debian,ubuntu,rocky}/build.log`
- **Sync logs**: `$BASE_LOG_DIR/{debian,ubuntu,rocky}/run.log`
- **Monitor reports**: `$BASE_LOG_DIR/mirror-status-report.txt`

### Health Checks

- Disk space monitoring (configurable threshold)
- Recent activity checks (files modified within 48 hours)
- Container status monitoring
- Systemd service status
- Network connectivity validation

## Features

### Resource Management
- Configurable memory and CPU limits for containers
- Disk space monitoring with alerts
- Process priority management (nice levels, IO scheduling)
- Concurrent run prevention via file locking

### Automation
- Systemd timer integration for scheduled syncs
- Automated container image cleanup
- Log rotation and retention management
- Error handling with notification support

### Monitoring & Alerting
- Email notifications via system mail
- Slack webhook integration
- Comprehensive health reporting
- Container status monitoring

### Security
- Non-root container execution where possible
- SELinux context management
- Proper file permissions and ownership
- Lock files to prevent concurrent execution

## Directory Structure

```
mirror-sync/
├── config/                 # Configuration files
│   ├── mirror-sync.conf   # Global configuration
│   └── local.conf         # Local overrides (created by setup)
├── lib/                   # Shared libraries
│   └── common.sh         # Common functions
├── base/                  # Base container image
│   ├── Containerfile     # Base image definition
│   └── healthcheck.sh    # Base health check
├── scripts/               # Management scripts
│   ├── setup-mirrors.sh  # Initial setup script
│   └── monitor-mirrors.sh # Monitoring script
├── apt-mirror/            # Debian/Ubuntu mirrors
│   ├── deb.debian.org/   # Debian-specific container
│   ├── archive.ubuntu.com/ # Ubuntu-specific container
│   ├── debian-build-and-sync.sh
│   ├── ubuntu-build-and-sync.sh
│   ├── *.service         # Systemd service files
│   └── *.timer           # Systemd timer files
└── rocky/                 # Rocky Linux mirror
    ├── dl.rockylinux.org/ # Rocky-specific container
    ├── rocky-build-and-sync.sh
    ├── *.service         # Systemd service files
    └── *.timer           # Systemd timer files
```

## Migration from Original Design

The optimized version maintains backward compatibility while adding:

- **Centralized Configuration**: No more scattered environment variables
- **Shared Components**: Reduced duplication, consistent behavior
- **Enhanced Monitoring**: Proactive health checks and alerting
- **Better Resource Management**: Configurable limits and cleanup
- **Improved Error Handling**: Notifications and detailed logging
- **Standardized Rocky Support**: Full parity with Debian/Ubuntu features

Existing configurations will continue to work, but new features require the optimized framework.

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure scripts are executable and SELinux contexts are correct
2. **Disk Space**: Monitor disk usage; sync operations require significant space
3. **Network Issues**: Check connectivity and firewall settings for repository access
4. **Container Build Failures**: Check container runtime installation and permissions

### Log Locations

- Service logs: `journalctl -u <service-name>`
- Container build logs: `$BASE_LOG_DIR/{distribution}/build.log`
- Sync operation logs: `$BASE_LOG_DIR/{distribution}/run.log`

### Getting Help

Check the monitoring report for system status:
```bash
./scripts/monitor-mirrors.sh report
cat $BASE_LOG_DIR/mirror-status-report.txt
```
