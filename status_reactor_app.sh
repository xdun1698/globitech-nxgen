#!/bin/bash

# Small Batch Reactor Scheduling System - Status Script
# This script checks the status of the Flask application and related services

# Configuration
APP_NAME="reactor_scheduling_app"
PID_FILE="/tmp/${APP_NAME}.pid"
LOG_FILE="/home/dbadmin/logs/${APP_NAME}.log"
ERROR_LOG="/home/dbadmin/logs/${APP_NAME}_error.log"
PORT=5000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[STATUS]${NC} $1"
}

# Header
echo "=================================================="
print_header "Small Batch Reactor Scheduling System Status"
echo "=================================================="
echo ""

# Check application status
print_header "Application Status:"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        print_status "✓ Application is RUNNING (PID: $PID)"
        
        # Get process details
        PROCESS_INFO=$(ps -p $PID -o pid,ppid,cmd,etime,pcpu,pmem --no-headers)
        echo "  Process Details: $PROCESS_INFO"
        
        # Check memory usage
        MEMORY_KB=$(ps -p $PID -o rss --no-headers)
        MEMORY_MB=$((MEMORY_KB / 1024))
        echo "  Memory Usage: ${MEMORY_MB} MB"
        
    else
        print_error "✗ PID file exists but process is not running"
        print_warning "  Stale PID file detected: $PID_FILE"
    fi
else
    # Check if Flask process is running without PID file
    FLASK_PID=$(pgrep -f "python.*app.py")
    if [ -n "$FLASK_PID" ]; then
        print_warning "✓ Flask process found but no PID file (PID: $FLASK_PID)"
        print_warning "  This may indicate an unmanaged process"
    else
        print_error "✗ Application is NOT RUNNING"
    fi
fi

echo ""

# Check port status and network configuration
print_header "Network Status:"

# Get current IP information
if [ -f "./get_local_ip.sh" ]; then
    CURRENT_IP=$(./get_local_ip.sh primary)
    INTERFACE_INFO=$(./get_local_ip.sh info | grep "Interface:" | cut -d' ' -f2)
    
    print_status "Current Network Configuration:"
    print_status "  Primary IP: $CURRENT_IP"
    print_status "  Interface: $INTERFACE_INFO"
    
    # Check if IP has changed
    IP_CHANGE_STATUS=$(./get_local_ip.sh check)
    if echo "$IP_CHANGE_STATUS" | grep -q "IP_CHANGED"; then
        print_warning "⚠ IP Address has changed since last check!"
        echo "$IP_CHANGE_STATUS" | grep -E "(Old IP|New IP)" | sed 's/^/  /'
    fi
else
    CURRENT_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
    print_status "Current IP: $CURRENT_IP"
fi

# Check port binding
if netstat -tlnp 2>/dev/null | grep -q ":$PORT.*LISTEN"; then
    LISTENING_PROCESS=$(netstat -tlnp 2>/dev/null | grep ":$PORT.*LISTEN" | awk '{print $7}')
    print_status "✓ Port $PORT is LISTENING ($LISTENING_PROCESS)"
    
    # Check if bound to all interfaces
    if netstat -tlnp 2>/dev/null | grep ":$PORT.*LISTEN" | grep -q "0.0.0.0:$PORT"; then
        print_status "✓ Bound to all interfaces (external access enabled)"
    else
        print_warning "⚠ May be bound to localhost only"
    fi
else
    print_error "✗ Port $PORT is NOT LISTENING"
fi

# Test HTTP connectivity (local and external)
if curl -s --connect-timeout 5 http://localhost:$PORT/api/status > /dev/null 2>&1; then
    print_status "✓ Local HTTP endpoint is RESPONDING"
    
    # Get API status if available
    API_RESPONSE=$(curl -s --connect-timeout 5 http://localhost:$PORT/api/status 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$API_RESPONSE" ]; then
        echo "  API Response: $API_RESPONSE"
    fi
else
    print_error "✗ Local HTTP endpoint is NOT RESPONDING"
fi

# Test external access if we have a valid IP
if [ "$CURRENT_IP" != "unknown" ] && [ "$CURRENT_IP" != "127.0.0.1" ] && [ "$CURRENT_IP" != "localhost" ]; then
    if curl -s --connect-timeout 5 http://$CURRENT_IP:$PORT/api/status > /dev/null 2>&1; then
        print_status "✓ External HTTP endpoint is RESPONDING"
        print_status "  External URL: http://$CURRENT_IP:$PORT"
    else
        print_warning "⚠ External HTTP endpoint may not be accessible"
        print_warning "  Check firewall settings for external access"
    fi
fi

echo ""

# Check database connectivity
print_header "Database Status:"
if netstat -tlnp 2>/dev/null | grep -q ":65432.*LISTEN"; then
    DB_PROCESS=$(netstat -tlnp 2>/dev/null | grep ":65432.*LISTEN" | awk '{print $7}')
    print_status "✓ PostgreSQL is RUNNING on port 65432 ($DB_PROCESS)"
else
    print_error "✗ PostgreSQL is NOT RUNNING on port 65432"
fi

echo ""

# Check log files
print_header "Log Files Status:"
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null)
    LOG_SIZE_MB=$((LOG_SIZE / 1024 / 1024))
    LAST_MODIFIED=$(stat -c %y "$LOG_FILE" 2>/dev/null)
    print_status "✓ Application log exists: $LOG_FILE"
    echo "  Size: ${LOG_SIZE_MB} MB, Last modified: $LAST_MODIFIED"
    
    # Show last few lines of log
    echo "  Last 3 log entries:"
    tail -n 3 "$LOG_FILE" 2>/dev/null | sed 's/^/    /'
else
    print_warning "✗ Application log not found: $LOG_FILE"
fi

if [ -f "$ERROR_LOG" ]; then
    ERROR_SIZE=$(stat -c%s "$ERROR_LOG" 2>/dev/null)
    if [ $ERROR_SIZE -gt 0 ]; then
        print_warning "⚠ Error log has content: $ERROR_LOG (${ERROR_SIZE} bytes)"
        echo "  Last 3 error entries:"
        tail -n 3 "$ERROR_LOG" 2>/dev/null | sed 's/^/    /'
    else
        print_status "✓ Error log is empty: $ERROR_LOG"
    fi
else
    print_warning "✗ Error log not found: $ERROR_LOG"
fi

echo ""

# System resources
print_header "System Resources:"
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
print_status "System Load Average:$LOAD_AVG"

MEMORY_INFO=$(free -h | grep "Mem:")
print_status "Memory: $MEMORY_INFO"

DISK_USAGE=$(df -h /home/dbadmin | tail -1)
print_status "Disk Usage (app directory): $DISK_USAGE"

echo ""

# Summary
print_header "Summary:"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        if curl -s --connect-timeout 5 http://localhost:$PORT/api/status > /dev/null 2>&1; then
            print_status "✓ System is HEALTHY and OPERATIONAL"
        else
            print_warning "⚠ System is running but HTTP endpoint not responding"
        fi
    else
        print_error "✗ System is DOWN (stale PID file)"
    fi
else
    print_error "✗ System is DOWN (no PID file)"
fi

echo "=================================================="
