#!/bin/bash

# Small Batch Reactor Scheduling System - Shutdown Script
# This script stops the Flask application gracefully

# Configuration
APP_NAME="reactor_scheduling_app"
PID_FILE="/tmp/${APP_NAME}.pid"
LOG_FILE="/home/dbadmin/logs/${APP_NAME}.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if PID file exists
if [ ! -f "$PID_FILE" ]; then
    print_warning "PID file not found. Application may not be running."
    
    # Try to find the process anyway
    FLASK_PID=$(pgrep -f "python.*app.py")
    if [ -n "$FLASK_PID" ]; then
        print_status "Found Flask process with PID: $FLASK_PID"
        print_status "Attempting to stop it..."
        kill -TERM $FLASK_PID
        sleep 3
        
        # Check if process is still running
        if ps -p $FLASK_PID > /dev/null 2>&1; then
            print_warning "Process still running. Forcing termination..."
            kill -KILL $FLASK_PID
            sleep 1
        fi
        
        if ps -p $FLASK_PID > /dev/null 2>&1; then
            print_error "Failed to stop the process"
            exit 1
        else
            print_status "Application stopped successfully"
        fi
    else
        print_warning "No Flask application process found"
    fi
    exit 0
fi

# Read PID from file
PID=$(cat "$PID_FILE")

# Check if process is running
if ! ps -p $PID > /dev/null 2>&1; then
    print_warning "Process with PID $PID is not running"
    print_status "Cleaning up PID file..."
    rm -f "$PID_FILE"
    exit 0
fi

print_status "Stopping Small Batch Reactor Scheduling System (PID: $PID)..."

# Try graceful shutdown first
kill -TERM $PID

# Wait for graceful shutdown
TIMEOUT=10
COUNTER=0

while [ $COUNTER -lt $TIMEOUT ]; do
    if ! ps -p $PID > /dev/null 2>&1; then
        print_status "Application stopped gracefully"
        rm -f "$PID_FILE"
        exit 0
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
    echo -n "."
done

echo ""
print_warning "Graceful shutdown timed out. Forcing termination..."

# Force kill if graceful shutdown failed
kill -KILL $PID
sleep 2

# Verify the process is stopped
if ps -p $PID > /dev/null 2>&1; then
    print_error "Failed to stop the application"
    exit 1
else
    print_status "Application forcefully terminated"
    rm -f "$PID_FILE"
fi

# Also clean up any other Flask processes that might be running
OTHER_PIDS=$(pgrep -f "python.*app.py" | grep -v $PID)
if [ -n "$OTHER_PIDS" ]; then
    print_status "Cleaning up other Flask processes..."
    echo $OTHER_PIDS | xargs kill -TERM
    sleep 2
    echo $OTHER_PIDS | xargs kill -KILL 2>/dev/null
fi

print_status "Shutdown complete"
