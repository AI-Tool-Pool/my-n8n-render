#!/usr/bin/env bash

# Enhanced health check script for n8n on Render with PostgreSQL
# Provides comprehensive validation of environment, database, and n8n service
# Optimized for free tier resource limits with efficient checks

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly TIMEOUT_SECONDS=10
readonly DB_TIMEOUT=5
readonly HTTP_TIMEOUT=10
readonly MAX_RETRIES=3

# Colors for output (if terminal supports it)
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    readonly RED=$(tput setaf 1)
    readonly GREEN=$(tput setaf 2)
    readonly YELLOW=$(tput setaf 3)
    readonly BLUE=$(tput setaf 4)
    readonly RESET=$(tput sgr0)
else
    readonly RED="" GREEN="" YELLOW="" BLUE="" RESET=""
fi

# Logging functions
log_info() {
    echo "${BLUE}ℹ INFO:${RESET} $*"
}

log_success() {
    echo "${GREEN}✅ SUCCESS:${RESET} $*"
}

log_warning() {
    echo "${YELLOW}⚠ WARNING:${RESET} $*"
}

log_error() {
    echo "${RED}❌ ERROR:${RESET} $*"
}

# Health check state
declare -g HEALTH_STATUS=0
declare -g TOTAL_CHECKS=0
declare -g PASSED_CHECKS=0

# Track check result
track_check() {
    local result=$1
    local check_name="$2"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ $result -eq 0 ]]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        log_success "$check_name"
    else
        HEALTH_STATUS=1
        log_error "$check_name"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check critical environment variables
check_environment() {
    log_info "Checking environment variables..."
    
    # Updated for Render PostgreSQL (fromDatabase references)
    local -a critical_vars=(
        "NODE_ENV"
        "WEBHOOK_URL"
        "DB_TYPE"
        "DB_POSTGRESDB_DATABASE"
        "DB_POSTGRESDB_HOST"
        "DB_POSTGRESDB_PORT"
        "DB_POSTGRESDB_USER"
        "DB_POSTGRESDB_PASSWORD"
        "N8N_ENCRYPTION_KEY"
    )
    
    # n8n-specific variables
    local -a n8n_vars=(
        "N8N_LOG_LEVEL"
        "N8N_METRICS"
        "EXECUTIONS_PROCESS"
        "EXECUTIONS_TIMEOUT"
        "EXECUTIONS_TIMEOUT_MAX"
    )
    
    local missing_vars=()
    local empty_vars=()
    
    # Check critical variables
    for var in "${critical_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        elif [[ -z "${!var}" ]]; then
            empty_vars+=("$var")
        fi
    done
    
    # Check n8n variables (warnings only)
    for var in "${n8n_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_warning "Optional n8n variable not set: $var"
        fi
    done
    
    # Report results
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        track_check 1 "Environment check - Missing variables: ${missing_vars[*]}"
        return 1
    elif [[ ${#empty_vars[@]} -gt 0 ]]; then
        track_check 1 "Environment check - Empty variables: ${empty_vars[*]}"
        return 1
    else
        track_check 0 "Environment variables configured"
        return 0
    fi
}

# Check PostgreSQL database connectivity
check_database() {
    log_info "Testing PostgreSQL database connection..."
    
    local host="${DB_POSTGRESDB_HOST:-localhost}"
    local port="${DB_POSTGRESDB_PORT:-5432}"
    local database="${DB_POSTGRESDB_DATABASE:-postgres}"
    local user="${DB_POSTGRESDB_USER:-postgres}"
    
    # Test network connectivity to database
    if command_exists nc; then
        if timeout "$DB_TIMEOUT" nc -z "$host" "$port" >/dev/null 2>&1; then
            log_success "Database network connectivity to $host:$port"
        else
            track_check 1 "Database network connectivity failed to $host:$port"
            return 1
        fi
    else
        log_warning "netcat (nc) not available for network connectivity test"
    fi
    
    # Test PostgreSQL connection with psql if available
    if command_exists psql; then
        local conn_string="postgresql://$user:${DB_POSTGRESDB_PASSWORD}@$host:$port/$database"
        
        if timeout "$DB_TIMEOUT" psql "$conn_string" -c "SELECT 1;" >/dev/null 2>&1; then
            track_check 0 "PostgreSQL connection and query test"
        else
            track_check 1 "PostgreSQL connection test failed"
            return 1
        fi
    else
        log_warning "psql not available for database connection test"
        # Fall back to basic connectivity test result
        track_check 0 "Database connectivity (basic network test only)"
    fi
    
    return 0
}

# Check n8n service health
check_n8n_service() {
    log_info "Checking n8n service health..."
    
    local n8n_port="${PORT:-5678}"
    local health_url="http://localhost:$n8n_port/healthz"
    local webhook_url="${WEBHOOK_URL:-}"
    
    # Check if n8n process is running
    if pgrep -f "n8n" >/dev/null 2>&1; then
        log_success "n8n process is running"
    else
        track_check 1 "n8n process not found"
        return 1
    fi
    
    # Check n8n health endpoint
    if command_exists curl; then
        local http_code
        if http_code=$(timeout "$HTTP_TIMEOUT" curl -s -o /dev/null -w "%{http_code}" "$health_url" 2>/dev/null); then
            if [[ "$http_code" == "200" ]]; then
                track_check 0 "n8n health endpoint responding"
            else
                track_check 1 "n8n health endpoint returned HTTP $http_code"
                return 1
            fi
        else
            track_check 1 "n8n health endpoint not accessible"
            return 1
        fi
    elif command_exists wget; then
        if timeout "$HTTP_TIMEOUT" wget -q --spider "$health_url" >/dev/null 2>&1; then
            track_check 0 "n8n health endpoint responding"
        else
            track_check 1 "n8n health endpoint not accessible"
            return 1
        fi
    else
        log_warning "Neither curl nor wget available for HTTP health check"
        track_check 0 "n8n service check (process only)"
    fi
    
    # Validate webhook URL format
    if [[ -n "$webhook_url" ]]; then
        if [[ "$webhook_url" =~ ^https?://[^/]+/.* ]]; then
            log_success "Webhook URL format is valid"
        else
            log_warning "Webhook URL format may be invalid: $webhook_url"
        fi
    fi
    
    return 0
}

# Check system resources (free tier optimized)
check_system_resources() {
    log_info "Checking system resources..."
    
    # Memory check (free tier has limited memory)
    if command_exists free; then
        local memory_info
        memory_info=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
        log_info "Memory usage: $memory_info"
        
        # Warning at 85% memory usage
        local memory_pct
        memory_pct=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        if [[ $memory_pct -gt 85 ]]; then
            log_warning "High memory usage: ${memory_pct}%"
        fi
    fi
    
    # Disk space check
    if command_exists df; then
        local disk_usage
        disk_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
        log_info "Disk usage: ${disk_usage}%"
        
        if [[ $disk_usage -gt 85 ]]; then
            log_warning "High disk usage: ${disk_usage}%"
        fi
    fi
    
    # Load average check
    if [[ -r /proc/loadavg ]]; then
        local load_avg
        load_avg=$(cut -d' ' -f1 /proc/loadavg)
        log_info "Load average (1min): $load_avg"
    fi
    
    track_check 0 "System resources checked"
    return 0
}

# Check Docker environment (if applicable)
check_docker_environment() {
    if [[ -f /.dockerenv ]] || command_exists docker; then
        log_info "Running in Docker environment"
        
        # Check if running as non-root user (security best practice)
        if [[ $(id -u) -eq 0 ]]; then
            log_warning "Running as root user (security risk)"
        else
            log_success "Running as non-root user"
        fi
        
        # Check for distroless indicators
        if [[ ! -f /etc/os-release ]] && [[ ! -f /usr/bin/apt ]]; then
            log_success "Appears to be running in distroless container"
        fi
        
        track_check 0 "Docker environment validated"
    else
        log_info "Not running in Docker environment"
        track_check 0 "Non-Docker environment"
    fi
    
    return 0
}

# Generate health summary
generate_summary() {
    echo
    echo "=================================="
    echo "         HEALTH CHECK SUMMARY"
    echo "=================================="
    echo "Total checks: $TOTAL_CHECKS"
    echo "Passed: $PASSED_CHECKS"
    echo "Failed: $((TOTAL_CHECKS - PASSED_CHECKS))"
    
    if [[ $HEALTH_STATUS -eq 0 ]]; then
        log_success "All critical health checks passed"
        echo "Status: ${GREEN}HEALTHY${RESET}"
    else
        log_error "Some health checks failed"
        echo "Status: ${RED}UNHEALTHY${RESET}"
    fi
    
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "=================================="
}

# Main execution
main() {
    echo "🏥 n8n Health Check on Render"
    echo "=============================="
    echo "Script: $SCRIPT_NAME"
    echo "Environment: ${NODE_ENV:-development}"
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo

    # Run all health checks
    check_environment
    check_database
    check_n8n_service
    check_system_resources
    check_docker_environment
    
    # Generate summary
    generate_summary
    
    # Exit with appropriate status
    exit $HEALTH_STATUS
}

# Handle script interruption
trap 'log_error "Health check interrupted"; exit 130' INT TERM

# Run main function
main "$@"