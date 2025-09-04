#!/bin/bash

# Enhanced Port Killer - Optimized for VM Development
# Usage: ./kill_ports.sh [options]
# Options: -y (non-interactive), -p PORT (specific port), -r RANGE (port range per family)

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Configuration
DEFAULT_RANGE=5
INTERACTIVE=true
SPECIFIC_PORT=""
BASE_PORTS=(3000 3001 4000 4321 5000 5173 8000 8080 9000 9090)

# Parse arguments
parse_arguments() {
    while getopts "yp:r:h" opt; do
        case $opt in
            y)
                INTERACTIVE=false
                ;;
            p)
                SPECIFIC_PORT="$OPTARG"
                ;;
            r)
                if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 1 ] && [ "$OPTARG" -le 20 ]; then
                    DEFAULT_RANGE="$OPTARG"
                else
                    print_error "Invalid range: $OPTARG (must be 1-20)"
                    exit 1
                fi
                ;;
            h)
                show_help
                exit 0
                ;;
            *)
                print_error "Invalid option"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
Enhanced Port Killer - Kill processes on development ports

Usage: ./kill_ports.sh [options]

Options:
  -y              Non-interactive mode (kill all without confirmation)
  -p PORT         Kill specific port only
  -r RANGE        Port range per family (default: 5, max: 20)  
  -h              Show this help

Examples:
  ./kill_ports.sh                 # Interactive mode, scan default ports
  ./kill_ports.sh -y              # Kill all found processes automatically
  ./kill_ports.sh -p 3000         # Kill only port 3000
  ./kill_ports.sh -r 10 -y        # Scan 10 ports per family, auto-kill

Default ports scanned: 3000-3004, 4000-4004, 4321-4325, 5000-5004, 
                      5173-5177, 8000-8004, 8080-8084, 9000-9004, 9090-9094
EOF
}

check_dependencies() {
    if ! command_exists lsof; then
        print_error "lsof not found. Install with: sudo apt-get install lsof"
        exit 1
    fi
}

kill_specific_port() {
    local port="$1"
    
    print_status "Checking port $port..."
    
    local pids
    pids=$(lsof -ti ":$port" 2>/dev/null || true)
    
    if [[ -z "$pids" ]]; then
        print_info "Port $port is free"
        return 0
    fi
    
    # Show process info
    print_warning "Found processes on port $port:"
    for pid in $pids; do
        local cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        local full_cmd=$(ps -p "$pid" -o args= 2>/dev/null || echo "unknown")
        echo "  PID $pid: $cmd ($full_cmd)"
    done
    
    # Confirm if interactive
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! ask_user "Kill processes on port $port?" "y"; then
            print_info "Skipping port $port"
            return 0
        fi
    fi
    
    # Kill processes
    local killed=0
    local failed=0
    
    for pid in $pids; do
        if kill -TERM "$pid" 2>/dev/null; then
            print_success "Terminated PID $pid"
            ((killed++))
        else
            print_error "Failed to terminate PID $pid"
            ((failed++))
        fi
    done
    
    # Wait and force kill if needed
    if [[ $killed -gt 0 ]]; then
        sleep 2
        
        local remaining
        remaining=$(lsof -ti ":$port" 2>/dev/null || true)
        if [[ -n "$remaining" ]]; then
            print_warning "Force killing remaining processes on port $port..."
            for pid in $remaining; do
                if kill -KILL "$pid" 2>/dev/null; then
                    print_success "Force killed PID $pid"
                fi
            done
        fi
    fi
    
    # Final check
    if lsof -ti ":$port" >/dev/null 2>&1; then
        print_error "Port $port still occupied"
        return 1
    else
        print_success "Port $port is now free"
        return 0
    fi
}

scan_and_kill_ports() {
    print_header "Port Scanner & Process Killer"
    
    if [[ "$INTERACTIVE" == "false" ]]; then
        print_warning "Running in NON-INTERACTIVE mode - will kill all found processes!"
    fi
    
    # Arrays to store results
    local found_ports=()
    local found_pids=()
    local found_commands=()
    
    print_status "Scanning ports..."
    
    # Scan port ranges
    for base_port in "${BASE_PORTS[@]}"; do
        for ((i=0; i<DEFAULT_RANGE; i++)); do
            local port=$((base_port + i))
            
            # Get PIDs using port
            local pids
            pids=$(lsof -ti ":$port" 2>/dev/null || true)
            
            if [[ -n "$pids" ]]; then
                print_info "Port $port: OCCUPIED"
                
                for pid in $pids; do
                    local cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                    local full_cmd=$(ps -p "$pid" -o args= 2>/dev/null || echo "unknown")
                    
                    found_ports+=("$port")
                    found_pids+=("$pid")
                    found_commands+=("$cmd|$full_cmd")
                    
                    print_dim "  └─ PID $pid ($cmd)"
                done
            fi
        done
    done
    
    # Check if any processes found
    if [[ ${#found_pids[@]} -eq 0 ]]; then
        print_success "No processes found on scanned ports! 🎉"
        return 0
    fi
    
    # Display summary
    print_warning "Found ${#found_pids[@]} process(es) on ${#found_ports[@]} port(s):"
    echo ""
    printf "%-8s %-8s %-15s %s\n" "PORT" "PID" "COMMAND" "FULL COMMAND"
    printf "%-8s %-8s %-15s %s\n" "----" "---" "-------" "------------"
    
    for ((i=0; i<${#found_pids[@]}; i++)); do
        IFS='|' read -r cmd full_cmd <<< "${found_commands[$i]}"
        printf "%-8s %-8s %-15s %s\n" "${found_ports[$i]}" "${found_pids[$i]}" "$cmd" "${full_cmd:0:50}$([ ${#full_cmd} -gt 50 ] && echo '...')"
    done
    
    echo ""
    
    # Confirm if interactive
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! ask_user "Kill all these processes?" "y"; then
            print_info "No processes killed"
            return 0
        fi
    fi
    
    # Kill processes
    print_status "Killing processes..."
    
    local killed=0
    local failed=0
    
    # Group by unique PIDs to avoid duplicates
    local unique_pids
    IFS=$'\n' read -d '' -r -a unique_pids <<< "$(printf '%s\n' "${found_pids[@]}" | sort -u)" || true
    
    for pid in "${unique_pids[@]}"; do
        if kill -TERM "$pid" 2>/dev/null; then
            print_success "Terminated PID $pid"
            ((killed++))
        else
            print_error "Failed to terminate PID $pid"
            ((failed++))
        fi
    done
    
    # Wait for graceful termination
    if [[ $killed -gt 0 ]]; then
        print_dim "Waiting for graceful termination..."
        sleep 3
        
        # Force kill remaining
        print_status "Checking for stubborn processes..."
        local force_killed=0
        
        for pid in "${unique_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                if kill -KILL "$pid" 2>/dev/null; then
                    print_warning "Force killed PID $pid"
                    ((force_killed++))
                fi
            fi
        done
        
        if [[ $force_killed -gt 0 ]]; then
            print_warning "Force killed $force_killed stubborn process(es)"
        fi
    fi
    
    # Final summary
    echo ""
    print_header "Summary"
    print_success "Processes terminated: $killed"
    [[ $failed -gt 0 ]] && print_error "Failed to kill: $failed"
    
    # Quick final verification
    local remaining=0
    for base_port in "${BASE_PORTS[@]}"; do
        for ((i=0; i<DEFAULT_RANGE; i++)); do
            local port=$((base_port + i))
            if lsof -ti ":$port" >/dev/null 2>&1; then
                ((remaining++))
            fi
        done
    done
    
    if [[ $remaining -eq 0 ]]; then
        print_success "All target ports are now free! 🎉"
    else
        print_warning "$remaining process(es) still running on target ports"
    fi
}

show_port_status() {
    print_header "Port Status Overview"
    
    echo "Listening ports on this system:"
    if command_exists ss; then
        ss -tlnp | grep LISTEN | head -10
    else
        netstat -tlnp 2>/dev/null | grep LISTEN | head -10 || lsof -i -P -n | grep LISTEN | head -10
    fi
    
    echo ""
    print_info "Common development ports:"
    for port in 3000 3001 4000 5000 5173 8000 8080 9000; do
        if lsof -ti ":$port" >/dev/null 2>&1; then
            printf "  Port %-5s: %sOCCUPIED%s\n" "$port" "$RED" "$NC"
        else
            printf "  Port %-5s: %sFREE%s\n" "$port" "$GREEN" "$NC"
        fi
    done
}

main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Check dependencies
    check_dependencies
    
    # Handle specific port
    if [[ -n "$SPECIFIC_PORT" ]]; then
        if [[ ! "$SPECIFIC_PORT" =~ ^[0-9]+$ ]] || [[ "$SPECIFIC_PORT" -lt 1 ]] || [[ "$SPECIFIC_PORT" -gt 65535 ]]; then
            print_error "Invalid port number: $SPECIFIC_PORT"
            exit 1
        fi
        kill_specific_port "$SPECIFIC_PORT"
        exit $?
    fi
    
    # Show current status if interactive
    if [[ "$INTERACTIVE" == "true" ]]; then
        show_port_status
        echo ""
    fi
    
    # Main scanning and killing
    scan_and_kill_ports
}

# Run main function with all arguments
main "$@"