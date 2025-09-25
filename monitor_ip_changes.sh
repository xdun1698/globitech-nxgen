#!/bin/bash

# IP Change Monitor for Small Batch Reactor Scheduling System
# This script monitors for DHCP IP address changes and can take actions when changes occur

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[MONITOR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[IP-MONITOR]${NC} $1"
}

# Configuration
IP_CHECK_INTERVAL=60  # Check every 60 seconds
LOG_FILE="/home/dbadmin/logs/ip_monitor.log"
RESTART_ON_CHANGE=false
NOTIFY_ON_CHANGE=true

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --interval N     Check interval in seconds (default: 60)"
    echo "  --restart        Restart application when IP changes"
    echo "  --no-notify      Don't show notifications"
    echo "  --daemon         Run as background daemon"
    echo "  --stop           Stop running daemon"
    echo "  --status         Show daemon status"
    echo "  --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run with default settings"
    echo "  $0 --interval 30 --restart  # Check every 30s and restart on change"
    echo "  $0 --daemon                 # Run in background"
}

# Function to handle IP change
handle_ip_change() {
    local old_ip="$1"
    local new_ip="$2"
    
    print_warning "IP Address Changed!"
    print_warning "  Old IP: $old_ip"
    print_warning "  New IP: $new_ip"
    
    log_message "IP CHANGE: $old_ip -> $new_ip"
    
    if [ "$NOTIFY_ON_CHANGE" = true ]; then
        # Update any configuration files or notify external systems
        print_status "Updating system configuration..."
        
        # Update quick reference with new IP
        if [ -f "QUICK_REFERENCE.md" ]; then
            sed -i "s|http://[0-9.]*:5000|http://$new_ip:5000|g" QUICK_REFERENCE.md
            print_status "Updated QUICK_REFERENCE.md with new IP"
        fi
        
        # Log the change for external monitoring
        echo "IP_CHANGE_EVENT: $(date '+%Y-%m-%d %H:%M:%S') - $old_ip -> $new_ip" >> /tmp/reactor_ip_changes.log
    fi
    
    if [ "$RESTART_ON_CHANGE" = true ]; then
        print_status "Restarting application due to IP change..."
        if [ -f "./restart_reactor_app.sh" ]; then
            ./restart_reactor_app.sh
            log_message "Application restarted due to IP change"
        else
            print_error "restart_reactor_app.sh not found"
        fi
    fi
    
    # Show new connection information
    print_status "New connection URLs:"
    print_status "  Web Interface: http://$new_ip:5000"
    print_status "  API Status: http://$new_ip:5000/api/status"
}

# Function to monitor IP changes
monitor_ip_changes() {
    print_header "Starting IP Change Monitor"
    print_status "Check interval: ${IP_CHECK_INTERVAL}s"
    print_status "Restart on change: $RESTART_ON_CHANGE"
    print_status "Notifications: $NOTIFY_ON_CHANGE"
    print_status "Log file: $LOG_FILE"
    echo ""
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_message "IP Monitor started (PID: $$)"
    
    # Get initial IP
    if [ -f "./get_local_ip.sh" ]; then
        LAST_IP=$(./get_local_ip.sh primary)
    else
        LAST_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
    fi
    
    print_status "Initial IP: $LAST_IP"
    log_message "Initial IP: $LAST_IP"
    
    # Main monitoring loop
    while true; do
        sleep "$IP_CHECK_INTERVAL"
        
        # Get current IP
        if [ -f "./get_local_ip.sh" ]; then
            CURRENT_IP=$(./get_local_ip.sh primary)
        else
            CURRENT_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
        fi
        
        # Check for change
        if [ "$CURRENT_IP" != "$LAST_IP" ]; then
            handle_ip_change "$LAST_IP" "$CURRENT_IP"
            LAST_IP="$CURRENT_IP"
        else
            # Periodic status log (every 10 minutes)
            if [ $(($(date +%s) % 600)) -lt "$IP_CHECK_INTERVAL" ]; then
                log_message "IP stable: $CURRENT_IP"
            fi
        fi
    done
}

# Function to run as daemon
run_daemon() {
    local pid_file="/tmp/ip_monitor.pid"
    
    if [ -f "$pid_file" ]; then
        local existing_pid=$(cat "$pid_file")
        if ps -p "$existing_pid" > /dev/null 2>&1; then
            print_error "IP monitor is already running (PID: $existing_pid)"
            exit 1
        else
            rm -f "$pid_file"
        fi
    fi
    
    print_status "Starting IP monitor daemon..."
    nohup "$0" --monitor > /dev/null 2>&1 &
    local daemon_pid=$!
    echo "$daemon_pid" > "$pid_file"
    
    print_status "IP monitor daemon started (PID: $daemon_pid)"
    print_status "Log file: $LOG_FILE"
    print_status "Use '$0 --stop' to stop the daemon"
}

# Function to stop daemon
stop_daemon() {
    local pid_file="/tmp/ip_monitor.pid"
    
    if [ -f "$pid_file" ]; then
        local daemon_pid=$(cat "$pid_file")
        if ps -p "$daemon_pid" > /dev/null 2>&1; then
            kill "$daemon_pid"
            rm -f "$pid_file"
            print_status "IP monitor daemon stopped (PID: $daemon_pid)"
        else
            print_warning "Daemon not running, cleaning up PID file"
            rm -f "$pid_file"
        fi
    else
        print_warning "No daemon PID file found"
    fi
}

# Function to show daemon status
show_daemon_status() {
    local pid_file="/tmp/ip_monitor.pid"
    
    if [ -f "$pid_file" ]; then
        local daemon_pid=$(cat "$pid_file")
        if ps -p "$daemon_pid" > /dev/null 2>&1; then
            print_status "✓ IP monitor daemon is running (PID: $daemon_pid)"
            
            # Show current IP
            if [ -f "./get_local_ip.sh" ]; then
                local current_ip=$(./get_local_ip.sh primary)
                print_status "Current IP: $current_ip"
            fi
            
            # Show recent log entries
            if [ -f "$LOG_FILE" ]; then
                print_status "Recent log entries:"
                tail -5 "$LOG_FILE" | sed 's/^/  /'
            fi
        else
            print_error "✗ Daemon PID file exists but process not running"
            rm -f "$pid_file"
        fi
    else
        print_error "✗ IP monitor daemon is not running"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --interval)
            IP_CHECK_INTERVAL="$2"
            shift 2
            ;;
        --restart)
            RESTART_ON_CHANGE=true
            shift
            ;;
        --no-notify)
            NOTIFY_ON_CHANGE=false
            shift
            ;;
        --daemon)
            run_daemon
            exit 0
            ;;
        --stop)
            stop_daemon
            exit 0
            ;;
        --status)
            show_daemon_status
            exit 0
            ;;
        --monitor)
            # Internal flag for daemon mode
            monitor_ip_changes
            exit 0
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Default action - run monitor in foreground
monitor_ip_changes
