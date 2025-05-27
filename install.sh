#!/bin/bash
# DeepLX CLI Installer - Handles both install and updates
# Usage: curl -sSL https://raw.githubusercontent.com/juan-de-costa-rica/deeplx-cli/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
REPO="juan-de-costa-rica/deeplx-cli"
BINARY_NAME="translate"
INSTALL_DIR="/usr/local/bin"

print_header() {
    echo -e "${BLUE}${BOLD}"
    echo "╔═══════════════════════════════════════╗"
    echo "║         DeepLX CLI Installer          ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}▶${NC} ${BOLD}$1${NC}"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} ${BOLD}$1${NC}"
}

print_error() {
    echo -e "${RED}✗${NC} ${BOLD}Error:${NC} $1" >&2
}

# Check if already installed
check_current_version() {
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        local version
        version=$($BINARY_NAME --version 2>/dev/null | head -1 | grep -o 'v[0-9.]*' || echo "unknown")
        echo "$version"
    else
        echo ""
    fi
}

# Detect system
detect_arch() {
    case $(uname -m) in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) 
            print_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
}

detect_os() {
    case $(uname -s | tr '[:upper:]' '[:lower:]') in
        linux) echo "linux" ;;
        darwin) echo "darwin" ;;
        *)
            print_error "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
}

# Get latest version from GitHub
get_latest_version() {
    curl -sSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | grep '"tag_name":' | cut -d'"' -f4
}

# Main installation function
main() {
    print_header
    
    # Check dependencies
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    # Get system info
    local os arch current_version latest_version
    os=$(detect_os)
    arch=$(detect_arch)
    current_version=$(check_current_version)
    
    print_info "System: $os-$arch"
    
    # Check if update needed
    if [ -n "$current_version" ]; then
        print_info "Current version: $current_version"
    fi
    
    print_step "Checking latest version..."
    latest_version=$(get_latest_version)
    
    if [ -z "$latest_version" ]; then
        print_error "Could not fetch latest version"
        exit 1
    fi
    
    print_info "Latest version: $latest_version"
    
    # Check if already up to date
    if [ -n "$current_version" ]; then
        if [ "$current_version" = "$latest_version" ]; then
            print_success "Already up to date!"
            show_usage
            exit 0
        else
            print_step "Updating from $current_version to $latest_version..."
        fi
    else
        print_step "Installing DeepLX CLI..."
    fi
    
    # Download and install
    local tmp_dir binary_name download_url
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT
    
    binary_name="${BINARY_NAME}-${os}-${arch}"
    download_url="https://github.com/$REPO/releases/download/$latest_version/$binary_name"
    
    print_info "Downloading: $binary_name"
    print_info "From: $download_url"
    
    if ! curl -sSL --fail "$download_url" -o "$tmp_dir/$BINARY_NAME" 2>/dev/null; then
        print_error "Failed to download binary"
        print_info "Check: https://github.com/$REPO/releases"
        exit 1
    fi
    
    chmod +x "$tmp_dir/$BINARY_NAME"
    
    # Install
    print_step "Installing to $INSTALL_DIR..."
    if [ -w "$INSTALL_DIR" ]; then
        mv "$tmp_dir/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
    else
        print_info "Requesting sudo permission..."
        sudo mv "$tmp_dir/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
    fi
    
    # Verify
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        local installed_version
        installed_version=$($BINARY_NAME --version 2>/dev/null | head -1 || echo "unknown")
        print_success "Successfully installed: $installed_version"
        show_usage
    else
        print_error "Installation verification failed"
        exit 1
    fi
}

show_usage() {
    echo
    echo -e "${BOLD}🚀 Quick Start:${NC}"
    echo
    echo -e "${YELLOW}# Test the installation${NC}"
    echo -e "translate --version"
    echo
    echo -e "${YELLOW}# Set up your DeepLX server token (optional)${NC}"
    echo -e "export TOKEN=your_deeplx_server_token"
    echo
    echo -e "${YELLOW}# Basic translation${NC}"
    echo -e 'translate "Hello, world!"'
    echo
    echo -e "${YELLOW}# Translate to Spanish${NC}"
    echo -e 'translate -t es "How are you?"'
    echo
    echo -e "${YELLOW}# Show alternatives${NC}"
    echo -e 'translate --alternatives "Hello!"'
    echo
    echo -e "${YELLOW}# Configure defaults${NC}"
    echo -e "translate config set --url http://localhost:1188 --token your_token"
    echo
    echo -e "${YELLOW}# Get help${NC}"
    echo -e "translate --help"
    echo
    echo -e "${BOLD}📚 More info:${NC} https://github.com/$REPO"
    echo -e "${BOLD}🔄 To update:${NC} Run this installer again"
}

# Run main function
main "$@"
