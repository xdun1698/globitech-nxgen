#!/bin/bash

# Network Access Validation Script for Small Batch Reactor Scheduling System

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
    echo -e "${BLUE}[NETWORK]${NC} $1"
}

echo "=================================================="
print_header "Network Access Validation"
echo "=================================================="
echo ""

# Get server IP addresses using dynamic detection
print_header "Server Network Configuration:"

if [ -f "./get_local_ip.sh" ]; then
    PRIMARY_IP=$(./get_local_ip.sh primary)
    ALL_IPS=$(./get_local_ip.sh all)
    
    print_status "Primary IP (DHCP): $PRIMARY_IP"
    
    # Show interface details
    ./get_local_ip.sh info | while read line; do
        print_status "$line"
    done
    
    echo ""
    print_status "All available IPs:"
    for ip in $ALL_IPS; do
        if [ "$ip" = "$PRIMARY_IP" ]; then
            print_status "  $ip (primary)"
        else
            print_status "  $ip"
        fi
    done
    
    SERVER_IPS="$PRIMARY_IP $ALL_IPS"
else
    # Fallback method
    SERVER_IPS=$(ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | cut -d'/' -f1)
    PRIMARY_IP=$(echo $SERVER_IPS | awk '{print $1}')
    
    for ip in $SERVER_IPS; do
        print_status "Server IP: $ip"
    done
fi

# Check for IP changes
if [ -f "./get_local_ip.sh" ]; then
    echo ""
    print_header "DHCP Status Check:"
    IP_CHANGE_INFO=$(./get_local_ip.sh check)
    if echo "$IP_CHANGE_INFO" | grep -q "IP_CHANGED"; then
        print_warning "⚠ IP Address has changed since last check!"
        echo "$IP_CHANGE_INFO" | grep -E "(Old IP|New IP)" | sed 's/^/  /'
        print_warning "  External clients may need to update their connection URLs"
    else
        print_status "✓ IP Address is stable since last check"
    fi
fi

echo ""

# Check port binding
print_header "Port 5000 Binding Status:"
BINDING=$(netstat -tlnp 2>/dev/null | grep :5000)
if [ -n "$BINDING" ]; then
    print_status "✓ Port 5000 is bound and listening"
    echo "  $BINDING"
    
    if echo "$BINDING" | grep -q "0.0.0.0:5000"; then
        print_status "✓ Correctly bound to all interfaces (0.0.0.0)"
    else
        print_warning "⚠ May be bound to localhost only"
    fi
else
    print_error "✗ Port 5000 is not listening"
fi

echo ""

# Test local connectivity
print_header "Local Connectivity Tests:"
if curl -s --connect-timeout 5 http://localhost:5000/api/status > /dev/null; then
    print_status "✓ Local access (localhost:5000) - SUCCESS"
else
    print_error "✗ Local access (localhost:5000) - FAILED"
fi

# Test each server IP
for ip in $SERVER_IPS; do
    if curl -s --connect-timeout 5 http://$ip:5000/api/status > /dev/null; then
        print_status "✓ Server IP access ($ip:5000) - SUCCESS"
    else
        print_error "✗ Server IP access ($ip:5000) - FAILED"
    fi
done

echo ""

# Check firewall status
print_header "Firewall Status:"
UFW_STATUS=$(sudo ufw status 2>/dev/null | head -1)
if echo "$UFW_STATUS" | grep -q "inactive"; then
    print_status "✓ UFW firewall is inactive (not blocking)"
elif echo "$UFW_STATUS" | grep -q "active"; then
    print_warning "⚠ UFW firewall is active - checking rules..."
    sudo ufw status | grep 5000 || print_warning "  No specific rule for port 5000"
else
    print_warning "⚠ Could not determine firewall status"
fi

# Check iptables if available
if command -v iptables > /dev/null; then
    IPTABLES_RULES=$(sudo iptables -L INPUT -n 2>/dev/null | grep -i drop | wc -l)
    if [ $IPTABLES_RULES -gt 0 ]; then
        print_warning "⚠ iptables has $IPTABLES_RULES DROP rules - may affect connectivity"
    else
        print_status "✓ No blocking iptables rules detected"
    fi
fi

echo ""

# Application status check
print_header "Application Status:"
if pgrep -f "python.*app.py" > /dev/null; then
    APP_PID=$(pgrep -f "python.*app.py")
    print_status "✓ Flask application is running (PID: $APP_PID)"
    
    # Test API endpoint
    API_RESPONSE=$(curl -s --connect-timeout 5 http://localhost:5000/api/status 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$API_RESPONSE" ]; then
        print_status "✓ API endpoint responding"
        echo "  Response: $API_RESPONSE"
    else
        print_error "✗ API endpoint not responding"
    fi
else
    print_error "✗ Flask application is not running"
fi

echo ""

# Network route check
print_header "Network Route Information:"
DEFAULT_ROUTE=$(ip route | grep default | head -1)
print_status "Default route: $DEFAULT_ROUTE"

# Check if we can reach common external hosts (to verify general network connectivity)
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    print_status "✓ External network connectivity working"
else
    print_warning "⚠ External network connectivity may be limited"
fi

echo ""

# Provide connection instructions
print_header "Connection Instructions:"

if [ -n "$PRIMARY_IP" ] && [ "$PRIMARY_IP" != "127.0.0.1" ]; then
    print_status "🌐 Primary Access URL (recommended):"
    print_status "  http://$PRIMARY_IP:5000"
    echo ""
    
    print_status "📱 For your Mac/external devices:"
    print_status "  Main Interface: http://$PRIMARY_IP:5000"
    print_status "  System Status:  http://$PRIMARY_IP:5000/api/status"
    print_status "  Reactor Data:   http://$PRIMARY_IP:5000/api/reactors"
    print_status "  Active Schedule: http://$PRIMARY_IP:5000/api/schedule"
    print_status "  Utilization:    http://$PRIMARY_IP:5000/api/reactor-utilization"
    echo ""
fi

if [ $(echo $SERVER_IPS | wc -w) -gt 1 ]; then
    print_status "🔗 Alternative IP addresses:"
    for ip in $SERVER_IPS; do
        if [ "$ip" != "$PRIMARY_IP" ]; then
            print_status "  http://$ip:5000"
        fi
    done
    echo ""
fi

print_status "💡 DHCP Notice:"
print_status "  This server uses DHCP - IP address may change after reboot"
print_status "  Use './get_local_ip.sh primary' to get current IP"
print_status "  Use './validate_network_access.sh' to check for IP changes"

echo ""

# Test from server to itself using external IP
print_header "Self-Test Using External IP:"
MAIN_IP=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || echo "")
if [ -n "$MAIN_IP" ]; then
    print_status "Testing connection to $MAIN_IP:5000..."
    if curl -s --connect-timeout 5 http://$MAIN_IP:5000/api/status > /dev/null; then
        print_status "✓ Self-test using external IP - SUCCESS"
        print_status "Your Mac should be able to connect to: http://$MAIN_IP:5000"
    else
        print_error "✗ Self-test using external IP - FAILED"
        print_error "This indicates a network configuration issue"
    fi
fi

echo ""
echo "=================================================="
print_header "Validation completed"
echo "=================================================="

# Final recommendation
echo ""
print_header "Troubleshooting Steps if Mac cannot connect:"
echo "1. Verify your Mac and server are on the same network"
echo "2. Try accessing: http://192.168.1.135:5000"
echo "3. Check if your Mac's firewall is blocking outbound connections"
echo "4. Try using curl from your Mac: curl http://192.168.1.135:5000/api/status"
echo "5. Verify the server IP hasn't changed: ip addr show"
