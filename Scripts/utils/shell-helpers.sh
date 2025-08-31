#!/bin/sh

# Minimal Shell Utilities for FluentData Scripts
# POSIX-compliant helpers for consistent output and common operations

# Colors (POSIX-compatible)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
GRAY='\033[0;37m'
NC='\033[0m'

# Output functions
print_info() {
    printf "${BLUE}ℹ️  %s${NC}\n" "$1"
}

print_success() {
    printf "${GREEN}✅ %s${NC}\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠️  %s${NC}\n" "$1"
}

print_error() {
    printf "${RED}❌ %s${NC}\n" "$1"
}

print_debug() {
    if [ "${DEBUG:-}" = "true" ]; then
        printf "${GRAY}🐛 %s${NC}\n" "$1"
    fi
}

print_step() {
    printf "${PURPLE}🔄 %s${NC}\n" "$1"
}

print_blank() {
    printf "\n"
}

# Utility functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

file_exists() {
    [ -f "$1" ] && [ -r "$1" ]
}

# Platform detection
is_macos() {
    [ "$(uname -s)" = "Darwin" ]
}

# Homebrew helpers
has_homebrew() {
    command_exists brew
}

brew_install() {
    package="$1"
    
    if ! is_macos; then
        print_error "Homebrew is only available on macOS"
        exit 1
    fi
    
    if ! has_homebrew; then
        print_error "Homebrew is not installed. Please install it first: https://brew.sh"
        exit 1
    fi
    
    print_info "Installing $package via Homebrew..."
    if brew install "$package"; then
        print_success "$package installed successfully"
    else
        print_error "Failed to install $package"
        exit 1
    fi
}

# Error handling
setup_error_handling() {
    set -e  # Exit on error
    
    if [ "${DEBUG:-}" = "true" ]; then
        set -x  # Enable debug output
        print_debug "Debug mode enabled"
    fi
}

# Script header
print_script_header() {
    script_name="$1"
    description="${2:-}"
    
    print_blank
    printf "\033[1;37m%s\033[0m\n" "$script_name"
    if [ -n "$description" ]; then
        print_info "$description"
    fi
    printf "${GRAY}────────────────────────────────────────${NC}\n"
    print_blank
}
