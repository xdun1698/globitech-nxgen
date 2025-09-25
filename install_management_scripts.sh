#!/bin/bash

# Small Batch Reactor Scheduling System - Installation Script
# This script sets up the management scripts and system integration

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
    echo -e "${BLUE}[INSTALL]${NC} $1"
}

# Header
echo "=================================================="
print_header "Small Batch Reactor Scheduling System Setup"
echo "=================================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. Consider running as dbadmin user for application scripts."
fi

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p /home/dbadmin/logs
chmod 755 /home/dbadmin/logs

# Make all scripts executable
print_status "Making scripts executable..."
chmod +x /home/dbadmin/start_reactor_app.sh
chmod +x /home/dbadmin/stop_reactor_app.sh
chmod +x /home/dbadmin/status_reactor_app.sh
chmod +x /home/dbadmin/restart_reactor_app.sh

# Check virtual environment
print_status "Checking Python virtual environment..."
if [ ! -d "/home/dbadmin/venv" ]; then
    print_warning "Virtual environment not found. Creating..."
    python3 -m venv /home/dbadmin/venv
    source /home/dbadmin/venv/bin/activate
    pip install --upgrade pip
    pip install flask psycopg2-binary
    print_status "Virtual environment created and packages installed"
else
    print_status "Virtual environment found"
    source /home/dbadmin/venv/bin/activate
    pip install flask psycopg2-binary --quiet
fi

# Check PostgreSQL
print_status "Checking PostgreSQL database..."
if netstat -tlnp 2>/dev/null | grep -q ":65432.*LISTEN"; then
    print_status "PostgreSQL is running on port 65432"
else
    print_warning "PostgreSQL is not running on port 65432"
    print_warning "Please ensure PostgreSQL is installed and configured"
fi

# Create symbolic links for easier access (optional)
print_status "Creating convenient command aliases..."
cat >> /home/dbadmin/.bashrc << 'EOF'

# Small Batch Reactor Scheduling System aliases
alias reactor-start='/home/dbadmin/start_reactor_app.sh'
alias reactor-stop='/home/dbadmin/stop_reactor_app.sh'
alias reactor-status='/home/dbadmin/status_reactor_app.sh'
alias reactor-restart='/home/dbadmin/restart_reactor_app.sh'
EOF

# Systemd service installation (optional)
if [ "$EUID" -eq 0 ]; then
    print_status "Installing systemd service..."
    cp /home/dbadmin/reactor-scheduling.service /etc/systemd/system/
    systemctl daemon-reload
    print_status "Systemd service installed. Enable with: systemctl enable reactor-scheduling"
else
    print_warning "Not running as root. Systemd service not installed."
    print_warning "To install systemd service, run as root:"
    print_warning "  sudo cp reactor-scheduling.service /etc/systemd/system/"
    print_warning "  sudo systemctl daemon-reload"
    print_warning "  sudo systemctl enable reactor-scheduling"
fi

# Create logrotate configuration
print_status "Creating log rotation configuration..."
cat > /home/dbadmin/logrotate.conf << 'EOF'
/home/dbadmin/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 dbadmin dbadmin
    postrotate
        /home/dbadmin/restart_reactor_app.sh > /dev/null 2>&1 || true
    endscript
}
EOF

# Test the installation
print_status "Testing installation..."
if [ -x "/home/dbadmin/status_reactor_app.sh" ]; then
    print_status "Running status check..."
    /home/dbadmin/status_reactor_app.sh
else
    print_error "Status script not executable"
fi

echo ""
print_header "Installation Summary:"
print_status "✓ Management scripts installed and executable"
print_status "✓ Log directory created: /home/dbadmin/logs"
print_status "✓ Virtual environment verified"
print_status "✓ Command aliases added to .bashrc"
print_status "✓ Log rotation configuration created"

if [ "$EUID" -eq 0 ]; then
    print_status "✓ Systemd service installed"
else
    print_warning "⚠ Systemd service requires root installation"
fi

echo ""
print_header "Next Steps:"
echo "1. Source your bashrc: source ~/.bashrc"
echo "2. Start the application: ./start_reactor_app.sh or reactor-start"
echo "3. Check status: ./status_reactor_app.sh or reactor-status"
echo "4. Review README_Management_Scripts.md for detailed usage"

if [ "$EUID" -ne 0 ]; then
    echo "5. (Optional) Install systemd service as root for system integration"
fi

echo ""
print_header "Available Commands:"
echo "  ./start_reactor_app.sh    or  reactor-start"
echo "  ./stop_reactor_app.sh     or  reactor-stop"
echo "  ./status_reactor_app.sh   or  reactor-status"
echo "  ./restart_reactor_app.sh  or  reactor-restart"

echo ""
echo "=================================================="
print_header "Installation completed successfully!"
echo "=================================================="
