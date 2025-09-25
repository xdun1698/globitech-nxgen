#!/bin/bash

# Small Batch Reactor Scheduling System - Restart Script
# This script restarts the Flask application by stopping and starting it

# Configuration
SCRIPT_DIR="/home/dbadmin"
START_SCRIPT="$SCRIPT_DIR/start_reactor_app.sh"
STOP_SCRIPT="$SCRIPT_DIR/stop_reactor_app.sh"
STATUS_SCRIPT="$SCRIPT_DIR/status_reactor_app.sh"

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
    echo -e "${BLUE}[RESTART]${NC} $1"
}

# Header
echo "=================================================="
print_header "Small Batch Reactor Scheduling System Restart"
echo "=================================================="
echo ""

# Check if required scripts exist
if [ ! -f "$START_SCRIPT" ]; then
    print_error "Start script not found: $START_SCRIPT"
    exit 1
fi

if [ ! -f "$STOP_SCRIPT" ]; then
    print_error "Stop script not found: $STOP_SCRIPT"
    exit 1
fi

# Make scripts executable if they aren't already
chmod +x "$START_SCRIPT" "$STOP_SCRIPT"
if [ -f "$STATUS_SCRIPT" ]; then
    chmod +x "$STATUS_SCRIPT"
fi

# Show current status
if [ -f "$STATUS_SCRIPT" ]; then
    print_header "Current Status:"
    bash "$STATUS_SCRIPT"
    echo ""
fi

# Stop the application
print_header "Stopping Application..."
bash "$STOP_SCRIPT"
STOP_EXIT_CODE=$?

if [ $STOP_EXIT_CODE -ne 0 ]; then
    print_warning "Stop script returned non-zero exit code: $STOP_EXIT_CODE"
    print_warning "Continuing with restart attempt..."
fi

echo ""

# Wait a moment before starting
print_status "Waiting 3 seconds before restart..."
sleep 3

# Start the application
print_header "Starting Application..."
bash "$START_SCRIPT"
START_EXIT_CODE=$?

echo ""

if [ $START_EXIT_CODE -eq 0 ]; then
    print_status "✓ Restart completed successfully"
    
    # Show final status
    if [ -f "$STATUS_SCRIPT" ]; then
        echo ""
        print_header "Post-Restart Status:"
        bash "$STATUS_SCRIPT"
    fi
else
    print_error "✗ Restart failed - start script returned exit code: $START_EXIT_CODE"
    print_error "Check the application logs for more details"
    exit 1
fi

echo ""
print_header "Restart operation completed"
echo "=================================================="
