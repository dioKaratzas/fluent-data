#!/bin/sh

# SwiftFormat Script for FluentData
# Checks for SwiftFormat installation and formats/lints Swift files
# Usage: ./Scripts/swift-format.sh [--lint]

# Source shell helpers
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/utils/shell-helpers.sh"

# Set up error handling
setup_error_handling

# Script configuration
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/configs/config.swiftformat"

# Check if SwiftFormat is installed
check_swiftformat() {
    print_step "Checking for SwiftFormat installation..."
    
    if command_exists swiftformat; then
        version=$(swiftformat --version 2>/dev/null || echo "unknown")
        print_success "SwiftFormat is installed (version: $version)"
        return 0
    else
        print_error "SwiftFormat is not installed or not in PATH"
        return 1
    fi
}

# Install SwiftFormat via Homebrew
install_swiftformat() {
    print_step "Installing SwiftFormat via Homebrew..."
    
    if ! has_homebrew; then
        print_error "Homebrew is not installed. Please install Homebrew first:"
        printf "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n"
        exit 1
    fi
    
    brew_install swiftformat
}

# Find all Swift files in the project
find_swift_files() {
    find "$PROJECT_ROOT/Sources" "$PROJECT_ROOT/Tests" -name "*.swift" -type f 2>/dev/null || true
}

# Get count of Swift files
count_swift_files() {
    swift_files=$(find_swift_files)
    
    if [ -z "$swift_files" ]; then
        echo "0"
    else
        echo "$swift_files" | wc -l | tr -d ' '
    fi
}

# Run SwiftFormat with config
run_swiftformat() {
    mode="$1"  # "format" or "lint"
    swift_files=$(find_swift_files)
    
    if [ -z "$swift_files" ]; then
        print_warning "No Swift files found to $mode"
        return 0
    fi
    
    file_count=$(count_swift_files)
    
    if [ "$mode" = "lint" ]; then
        print_info "Linting $file_count Swift files..."
    else
        print_info "Formatting $file_count Swift files..."
    fi
    
    # Build SwiftFormat arguments
    swiftformat_args=""
    
    # Add config file if it exists
    if file_exists "$CONFIG_FILE"; then
        print_debug "Using config file: $CONFIG_FILE"
        swiftformat_args="--config $CONFIG_FILE"
    else
        print_warning "Config file not found at $CONFIG_FILE, using default settings"
    fi
    
    # Add lint flag if in lint mode
    if [ "$mode" = "lint" ]; then
        swiftformat_args="$swiftformat_args --lint"
    fi
    
    # Run SwiftFormat
    if echo "$swift_files" | xargs swiftformat $swiftformat_args; then
        if [ "$mode" = "lint" ]; then
            print_success "All files are properly formatted"
        else
            print_success "Formatting completed"
        fi
        return 0
    else
        if [ "$mode" = "lint" ]; then
            print_error "Linting failed - files need formatting"
            print_blank
            print_info "To fix formatting issues, run:"
            printf "  ./Scripts/swift-format.sh\n"
            return 1
        else
            print_error "Formatting failed"
            exit 1
        fi
    fi
}

# Format Swift files
format_files() {
    run_swiftformat "format"
}

# Lint Swift files
lint_files() {
    run_swiftformat "lint"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

SwiftFormat automation script for FluentData project.

OPTIONS:
  --lint, -l     Lint files instead of formatting (check only)
  --help, -h     Show this help message
  --debug        Enable debug output

EXAMPLES:
  $0             Format all Swift files
  $0 --lint      Check if files need formatting (CI mode)
  $0 --debug     Format with debug output

CONFIGURATION:
  Config file: $CONFIG_FILE
  
For more information about SwiftFormat, visit:
  https://github.com/nicklockwood/SwiftFormat
EOF
}

# Main script logic
main() {
    mode="format"
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --lint|-l)
                mode="lint"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --debug)
                DEBUG=true
                export DEBUG
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                print_blank
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Print script header
    print_script_header "FluentData SwiftFormat Script" "Automated Swift code formatting and linting"
    
    print_info "Project root: $PROJECT_ROOT"
    print_info "Swift files found: $(count_swift_files)"
    print_blank
    
    # Validate requirements
    if ! is_macos; then
        print_warning "This script is designed for macOS. Some features may not work on other platforms."
    fi
    
    # Check if SwiftFormat is installed
    if ! check_swiftformat; then
        print_warning "SwiftFormat not found. Attempting to install..."
        install_swiftformat
        print_blank
    fi
    
    # Execute based on mode
    case $mode in
        format)
            print_step "Running SwiftFormat in format mode..."
            format_files
            ;;
        lint)
            print_step "Running SwiftFormat in lint mode..."
            if ! lint_files; then
                exit 1
            fi
            ;;
        *)
            print_error "Invalid mode: $mode"
            exit 1
            ;;
    esac
    
    print_blank
    print_success "Done!"
}

# Run main function with all arguments
main "$@"