#!/bin/bash

# IP Detection Utility for Small Batch Reactor Scheduling System
# This script provides reliable local IP address detection for DHCP environments

# Function to get the primary local IP address
get_primary_ip() {
    # Method 1: Use ip route to get the IP used for external connectivity
    local ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' 2>/dev/null)
    
    if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
        echo "$ip"
        return 0
    fi
    
    # Method 2: Get IP from default route interface
    local default_iface=$(ip route | grep default | head -1 | awk '{print $5}' 2>/dev/null)
    if [ -n "$default_iface" ]; then
        ip=$(ip addr show "$default_iface" 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}' | cut -d'/' -f1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi
    
    # Method 3: Get first non-loopback IP
    ip=$(ip addr show 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}' | cut -d'/' -f1)
    if [ -n "$ip" ]; then
        echo "$ip"
        return 0
    fi
    
    # Fallback
    echo "127.0.0.1"
    return 1
}

# Function to get all local IP addresses
get_all_ips() {
    ip addr show 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1
}

# Function to get network interface information
get_interface_info() {
    local primary_ip=$(get_primary_ip)
    local interface=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' 2>/dev/null)
    
    if [ -z "$interface" ]; then
        interface=$(ip route | grep default | head -1 | awk '{print $5}' 2>/dev/null)
    fi
    
    echo "Primary IP: $primary_ip"
    echo "Interface: ${interface:-unknown}"
    
    if [ -n "$interface" ]; then
        local mac=$(ip link show "$interface" 2>/dev/null | grep "link/ether" | awk '{print $2}')
        echo "MAC Address: ${mac:-unknown}"
    fi
}

# Function to check if IP has changed
check_ip_change() {
    local ip_file="/tmp/reactor_app_last_ip"
    local current_ip=$(get_primary_ip)
    local last_ip=""
    
    if [ -f "$ip_file" ]; then
        last_ip=$(cat "$ip_file")
    fi
    
    if [ "$current_ip" != "$last_ip" ]; then
        echo "$current_ip" > "$ip_file"
        echo "IP_CHANGED"
        echo "Old IP: ${last_ip:-none}"
        echo "New IP: $current_ip"
        return 0
    else
        echo "IP_UNCHANGED"
        echo "Current IP: $current_ip"
        return 1
    fi
}

# Function to get network status
get_network_status() {
    local primary_ip=$(get_primary_ip)
    local gateway=$(ip route | grep default | head -1 | awk '{print $3}' 2>/dev/null)
    local dns_servers=$(grep "nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -3 | tr '\n' ' ')
    
    echo "Network Status:"
    echo "  Primary IP: $primary_ip"
    echo "  Gateway: ${gateway:-unknown}"
    echo "  DNS Servers: ${dns_servers:-unknown}"
    
    # Test connectivity
    if ping -c 1 -W 2 "$gateway" > /dev/null 2>&1; then
        echo "  Gateway: ✓ Reachable"
    else
        echo "  Gateway: ✗ Unreachable"
    fi
    
    if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        echo "  Internet: ✓ Connected"
    else
        echo "  Internet: ✗ Disconnected"
    fi
}

# Main script logic
case "$1" in
    "primary"|"")
        get_primary_ip
        ;;
    "all")
        get_all_ips
        ;;
    "info")
        get_interface_info
        ;;
    "check")
        check_ip_change
        ;;
    "status")
        get_network_status
        ;;
    "help")
        echo "Usage: $0 [primary|all|info|check|status|help]"
        echo ""
        echo "Commands:"
        echo "  primary  - Get primary IP address (default)"
        echo "  all      - Get all IP addresses"
        echo "  info     - Get interface information"
        echo "  check    - Check if IP has changed"
        echo "  status   - Get network status"
        echo "  help     - Show this help"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
