#!/bin/bash

# Small Batch Reactor Scheduling System - Startup Script
# This script starts the Flask application and related services

# Configuration
APP_DIR="/home/dbadmin"
APP_NAME="reactor_scheduling_app"
VENV_PATH="/home/dbadmin/venv"
APP_FILE="app.py"  # Main Flask application file
PID_FILE="/tmp/${APP_NAME}.pid"
LOG_FILE="/home/dbadmin/logs/${APP_NAME}.log"
ERROR_LOG="/home/dbadmin/logs/${APP_NAME}_error.log"
PORT=${PORT:-5000}  # Default Flask port; can be overridden by environment

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

# Create necessary directories if they don't exist
mkdir -p /home/dbadmin/logs
mkdir -p /home/dbadmin/templates

# Check if application is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        print_warning "Application is already running with PID $PID"
        exit 1
    else
        print_warning "Stale PID file found. Removing..."
        rm -f "$PID_FILE"
    fi
fi

# Check if virtual environment exists
if [ ! -d "$VENV_PATH" ]; then
    print_error "Virtual environment not found at $VENV_PATH"
    print_error "Please create a virtual environment first"
    exit 1
fi

# Check if PostgreSQL is running
print_status "Checking PostgreSQL database connection..."
if ! netstat -tlnp | grep -q ":65432.*LISTEN"; then
    print_error "PostgreSQL is not running on port 65432"
    print_error "Please start PostgreSQL first"
    exit 1
fi

# Activate virtual environment and start the application
print_status "Starting Small Batch Reactor Scheduling System..."

cd "$APP_DIR"

# Check if app.py exists, if not create a basic one
if [ ! -f "$APP_FILE" ]; then
    print_warning "Main application file ($APP_FILE) not found"
    print_status "Creating basic Flask application structure..."
    
    # Create a basic Flask app if it doesn't exist
    cat > "$APP_FILE" << 'EOF'
from flask import Flask, render_template, request, jsonify
import psycopg2
import os
from datetime import datetime

app = Flask(__name__)

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'port': 65432,
    'database': 'reactor_scheduling',
    'user': 'dbadmin',
    'password': 'your_password_here'  # Update this
}

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def status():
    return jsonify({
        'status': 'running',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })

@app.route('/api/reactors')
def get_reactors():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("SELECT * FROM reactors LIMIT 10")
        reactors = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify({'reactors': reactors})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF
fi

# Start the application in background
source "$VENV_PATH/bin/activate"

# Install required packages if not present
pip install flask psycopg2-binary > /dev/null 2>&1

# Start the Flask application
export PORT
nohup python "$APP_FILE" > "$LOG_FILE" 2> "$ERROR_LOG" &
APP_PID=$!

# Save PID to file
echo $APP_PID > "$PID_FILE"

# Wait a moment and check if the application started successfully
sleep 3

if ps -p $APP_PID > /dev/null 2>&1; then
    print_status "Application started successfully!"
    print_status "PID: $APP_PID"
    print_status "Port: $PORT"
    print_status "Log file: $LOG_FILE"
    print_status "Error log: $ERROR_LOG"
    
    # Get server IP for external access using our IP detection utility
    if [ -f "./get_local_ip.sh" ]; then
        SERVER_IP=$(./get_local_ip.sh primary)
        INTERFACE_INFO=$(./get_local_ip.sh info | grep "Interface:" | cut -d' ' -f2)
        MAC_INFO=$(./get_local_ip.sh info | grep "MAC Address:" | cut -d' ' -f3)
    else
        SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "localhost")
        INTERFACE_INFO="unknown"
        MAC_INFO="unknown"
    fi
    
    print_status "Network Configuration:"
    print_status "  Primary IP: $SERVER_IP"
    print_status "  Interface: $INTERFACE_INFO"
    print_status "  MAC Address: $MAC_INFO"
    print_status "Local access: http://localhost:$PORT"
    if [ "$SERVER_IP" != "localhost" ] && [ "$SERVER_IP" != "127.0.0.1" ]; then
        print_status "External access: http://$SERVER_IP:$PORT"
        print_status "API endpoints: http://$SERVER_IP:$PORT/api/status"
    fi
    
    # Check if the application is responding
    sleep 2
    if curl -s http://localhost:$PORT/api/status > /dev/null 2>&1; then
        print_status "Application is responding to HTTP requests"
    else
        print_warning "Application started but may not be responding to HTTP requests yet"
        print_warning "Check the log files for more information"
    fi
else
    print_error "Failed to start application"
    print_error "Check error log: $ERROR_LOG"
    rm -f "$PID_FILE"
    exit 1
fi
