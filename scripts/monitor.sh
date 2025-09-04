#!/bin/bash

# VM Resource Monitor - Lightweight monitoring for remote development VMs
# Usage: ./monitor.sh [options]
# Options: --continuous, --alert, --json, --simple

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Configuration
CONTINUOUS=false
ALERT_MODE=false
JSON_OUTPUT=false
SIMPLE_OUTPUT=false
REFRESH_INTERVAL=2
CPU_ALERT_THRESHOLD=80
MEMORY_ALERT_THRESHOLD=85
DISK_ALERT_THRESHOLD=90

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --continuous|-c)
                CONTINUOUS=true
                shift
                ;;
            --alert|-a)
                ALERT_MODE=true
                shift
                ;;
            --json|-j)
                JSON_OUTPUT=true
                shift
                ;;
            --simple|-s)
                SIMPLE_OUTPUT=true
                shift
                ;;
            --interval)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    REFRESH_INTERVAL="$2"
                    shift 2
                else
                    print_error "Invalid interval: $2"
                    exit 1
                fi
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
VM Resource Monitor - Lightweight monitoring for development VMs

Usage: ./monitor.sh [options]

Options:
  --continuous, -c    Continuous monitoring (refresh every 2 seconds)
  --alert, -a         Show only resources above alert thresholds
  --json, -j          Output in JSON format
  --simple, -s        Simple output format (good for scripting)
  --interval N        Set refresh interval for continuous mode (seconds)
  --help, -h          Show this help

Examples:
  ./monitor.sh                    # Single snapshot
  ./monitor.sh --continuous       # Continuous monitoring
  ./monitor.sh --alert            # Show only concerning metrics
  ./monitor.sh --json             # JSON output for parsing

Alert Thresholds:
  CPU:    80%
  Memory: 85%
  Disk:   90%
EOF
}

# Get CPU usage percentage
get_cpu_usage() {
    if command_exists top; then
        # Use top for CPU usage (average over 1 second)
        top -bn2 -d1 | grep "Cpu(s)" | tail -1 | sed 's/%us,.*//g' | awk '{print $2}' | cut -d'%' -f1
    elif [[ -f /proc/stat ]]; then
        # Fallback to /proc/stat calculation
        awk '/^cpu / {usage=($2+$4)*100/($2+$4+$5)} END {print usage}' /proc/stat
    else
        echo "0"
    fi
}

# Get memory usage
get_memory_info() {
    if command_exists free; then
        free -m | awk 'NR==2{
            total=$2
            used=$3
            available=$7
            if (available == "") available = total - used
            usage_percent = (used/total) * 100
            printf "%.0f %.0f %.0f %.1f\n", total, used, available, usage_percent
        }'
    else
        echo "0 0 0 0"
    fi
}

# Get disk usage for root partition
get_disk_info() {
    df -h / | awk 'NR==2 {
        gsub(/%/, "", $5)
        print $2, $3, $4, $5
    }'
}

# Get system load
get_load_average() {
    if [[ -f /proc/loadavg ]]; then
        cut -d' ' -f1-3 /proc/loadavg
    else
        echo "0.00 0.00 0.00"
    fi
}

# Get number of CPU cores
get_cpu_cores() {
    nproc 2>/dev/null || echo "1"
}

# Get uptime
get_uptime() {
    if command_exists uptime; then
        uptime -p 2>/dev/null | sed 's/up //' || uptime | awk '{print $3}' | sed 's/,//'
    else
        echo "unknown"
    fi
}

# Get active connections count
get_connections() {
    if command_exists ss; then
        ss -tuln | grep -c LISTEN
    elif command_exists netstat; then
        netstat -tuln 2>/dev/null | grep -c LISTEN
    else
        echo "0"
    fi
}

# Get running processes count
get_process_count() {
    ps aux | wc -l
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [[ $bytes -gt 1073741824 ]]; then
        echo "$(( bytes / 1073741824 ))G"
    elif [[ $bytes -gt 1048576 ]]; then
        echo "$(( bytes / 1048576 ))M"
    elif [[ $bytes -gt 1024 ]]; then
        echo "$(( bytes / 1024 ))K"
    else
        echo "${bytes}B"
    fi
}

# Check if value exceeds threshold
exceeds_threshold() {
    local value=$1
    local threshold=$2
    awk -v val="$value" -v thresh="$threshold" 'BEGIN {print (val >= thresh) ? 1 : 0}'
}

# Display system information
show_system_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname)
    local kernel=$(uname -r)
    local arch=$(uname -m)
    
    if [[ "$SIMPLE_OUTPUT" == "true" ]]; then
        echo "$timestamp $hostname"
        return
    fi
    
    print_header "System Information - $timestamp"
    echo "Hostname: $hostname"
    echo "Kernel: $kernel ($arch)"
    echo "Uptime: $(get_uptime)"
    echo ""
}

# Display resource usage
show_resources() {
    # Get all metrics
    local cpu_usage=$(get_cpu_usage)
    local cpu_cores=$(get_cpu_cores)
    local load_avg=$(get_load_average)
    
    # Memory info (total used available usage_percent)
    read -r mem_total mem_used mem_available mem_usage_percent <<< "$(get_memory_info)"
    
    # Disk info (total used available usage_percent)
    read -r disk_total disk_used disk_available disk_usage_percent <<< "$(get_disk_info)"
    
    local connections=$(get_connections)
    local processes=$(get_process_count)
    
    # Round CPU usage
    cpu_usage=$(printf "%.1f" "$cpu_usage")
    
    # Check alert conditions
    local cpu_alert=$(exceeds_threshold "$cpu_usage" "$CPU_ALERT_THRESHOLD")
    local mem_alert=$(exceeds_threshold "$mem_usage_percent" "$MEMORY_ALERT_THRESHOLD")  
    local disk_alert=$(exceeds_threshold "$disk_usage_percent" "$DISK_ALERT_THRESHOLD")
    
    # JSON output
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "cpu": {
    "usage_percent": $cpu_usage,
    "cores": $cpu_cores,
    "load_average": "$(echo $load_avg | cut -d' ' -f1)",
    "alert": $([ "$cpu_alert" -eq 1 ] && echo "true" || echo "false")
  },
  "memory": {
    "total_mb": $mem_total,
    "used_mb": $mem_used,
    "available_mb": $mem_available,
    "usage_percent": $mem_usage_percent,
    "alert": $([ "$mem_alert" -eq 1 ] && echo "true" || echo "false")
  },
  "disk": {
    "total": "$disk_total",
    "used": "$disk_used", 
    "available": "$disk_available",
    "usage_percent": $disk_usage_percent,
    "alert": $([ "$disk_alert" -eq 1 ] && echo "true" || echo "false")
  },
  "network": {
    "listening_ports": $connections
  },
  "processes": $processes
}
EOF
        return
    fi
    
    # Simple output
    if [[ "$SIMPLE_OUTPUT" == "true" ]]; then
        echo "CPU:${cpu_usage}% MEM:${mem_usage_percent}% DISK:${disk_usage_percent}% LOAD:$(echo $load_avg | cut -d' ' -f1)"
        return
    fi
    
    # Alert mode - only show if there are alerts
    if [[ "$ALERT_MODE" == "true" ]]; then
        local has_alerts=false
        
        if [[ "$cpu_alert" -eq 1 ]]; then
            print_error "CPU usage high: ${cpu_usage}% (threshold: ${CPU_ALERT_THRESHOLD}%)"
            has_alerts=true
        fi
        
        if [[ "$mem_alert" -eq 1 ]]; then
            print_error "Memory usage high: ${mem_usage_percent}% (threshold: ${MEMORY_ALERT_THRESHOLD}%)"
            has_alerts=true
        fi
        
        if [[ "$disk_alert" -eq 1 ]]; then
            print_error "Disk usage high: ${disk_usage_percent}% (threshold: ${DISK_ALERT_THRESHOLD}%)"
            has_alerts=true
        fi
        
        if [[ "$has_alerts" == "false" ]]; then
            print_success "All resources within normal ranges"
        fi
        
        return
    fi
    
    # Full display
    print_header "Resource Usage"
    
    # CPU
    local cpu_color="$GREEN"
    [[ "$cpu_alert" -eq 1 ]] && cpu_color="$RED"
    printf "CPU Usage:      ${cpu_color}%5.1f%%${NC} (%d cores)\n" "$cpu_usage" "$cpu_cores"
    printf "Load Average:   %s\n" "$load_avg"
    
    # Memory
    local mem_color="$GREEN"
    [[ "$mem_alert" -eq 1 ]] && mem_color="$RED"
    printf "Memory:         ${mem_color}%5.1f%%${NC} (%dM used / %dM total, %dM available)\n" \
        "$mem_usage_percent" "$mem_used" "$mem_total" "$mem_available"
    
    # Disk
    local disk_color="$GREEN"
    [[ "$disk_alert" -eq 1 ]] && disk_color="$RED"
    printf "Disk Usage:     ${disk_color}%5s${NC} (%s used / %s total, %s available)\n" \
        "${disk_usage_percent}%" "$disk_used" "$disk_total" "$disk_available"
    
    echo ""
    
    # Additional info
    print_header "System Activity"
    printf "Active Processes: %d\n" "$processes"
    printf "Listening Ports:  %d\n" "$connections"
    echo ""
    
    # Show top processes if not in continuous mode
    if [[ "$CONTINUOUS" == "false" ]]; then
        show_top_processes
    fi
}

show_top_processes() {
    print_header "Top Processes (CPU)"
    
    if command_exists ps; then
        # Show top 5 CPU processes
        echo "  PID    CPU%  MEM%  COMMAND"
        echo "  ----   ----  ----  -------"
        ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "  %-6s %4.1f%% %4.1f%%  %s\n", $2, $3, $4, $11}'
    fi
    
    echo ""
    
    # Show memory usage
    print_header "Top Processes (Memory)"
    
    if command_exists ps; then
        echo "  PID    CPU%  MEM%  COMMAND"
        echo "  ----   ----  ----  -------"
        ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "  %-6s %4.1f%% %4.1f%%  %s\n", $2, $3, $4, $11}'
    fi
}

show_network_info() {
    print_header "Network Information"
    
    # Show listening ports
    echo "Listening services:"
    if command_exists ss; then
        ss -tlnp | awk 'NR>1 {print "  " $4 " (" $1 ")"}' | head -10
    elif command_exists netstat; then
        netstat -tlnp 2>/dev/null | awk '/LISTEN/ {print "  " $4 " (" $1 ")"}' | head -10
    fi
    
    echo ""
    
    # Show network interfaces
    echo "Network interfaces:"
    if command_exists ip; then
        ip addr show | grep -E '^\d+:|inet ' | awk '/^[0-9]+:/ {iface=$2} /inet / {print "  " iface " " $2}' | head -5
    else
        ifconfig 2>/dev/null | grep -E '^[a-zA-Z]|inet ' | awk '/^[a-zA-Z]/ {iface=$1} /inet / {print "  " iface " " $2}' | head -5
    fi
}

continuous_monitor() {
    print_info "Starting continuous monitoring (Ctrl+C to stop)"
    print_dim "Refresh interval: ${REFRESH_INTERVAL}s"
    echo ""
    
    # Trap Ctrl+C
    trap 'print_info "Monitoring stopped"; exit 0' INT
    
    while true; do
        # Clear screen
        clear
        
        # Show info
        show_system_info
        show_resources
        
        # Show refresh info
        print_dim "Refreshing in ${REFRESH_INTERVAL}s... (Ctrl+C to stop)"
        
        sleep "$REFRESH_INTERVAL"
    done
}

main() {
    # Parse arguments
    parse_arguments "$@"
    
    if [[ "$CONTINUOUS" == "true" ]]; then
        continuous_monitor
    else
        # Single run
        if [[ "$JSON_OUTPUT" != "true" && "$SIMPLE_OUTPUT" != "true" ]]; then
            show_system_info
        fi
        
        show_resources
        
        if [[ "$JSON_OUTPUT" != "true" && "$SIMPLE_OUTPUT" != "true" && "$ALERT_MODE" != "true" ]]; then
            show_network_info
        fi
    fi
}

# Run main function
main "$@"