#!/bin/bash
# MonoClaw Installer - Helper Functions

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Log a section header
log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}=== $1 ===${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Log a step
log_step() {
    echo -e "${GREEN}>>> $1${NC}"
}

# Log an info message
log_info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

# Log an error message
log_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Log a warning message
log_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Run a script with logging
run_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")

    if [ ! -f "$script_path" ]; then
        log_error "Script not found: $script_path"
        exit 1
    fi

    log_step "Running $script_name..."
    source "$script_path"
}

# Validate that a variable is set
require_var() {
    local var_name="$1"
    local var_value="${!var_name}"

    if [ -z "$var_value" ]; then
        log_error "Required variable $var_name is not set"
        exit 1
    fi
}

# Generate a random password
generate_password() {
    local length="${1:-24}"
    openssl rand -hex "$length"
}

# Generate a base64 password
generate_password_base64() {
    local length="${1:-24}"
    openssl rand -base64 "$length"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install a package if not already installed
ensure_package() {
    local package="$1"
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        apt install -y "$package"
    fi
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    local owner="${2:-}"
    local perms="${3:-755}"

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
    fi

    if [ -n "$owner" ]; then
        chown "$owner" "$dir"
    fi

    chmod "$perms" "$dir"
}

# Print a divider line
print_divider() {
    echo "--------------------------------------------------------------------"
}

# Print a box with a message
print_box() {
    local message="$1"
    echo "======================================="
    echo "$message"
    echo "======================================="
}

log_section "Starting MonoClaw Setup Script"
