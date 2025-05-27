#!/bin/bash
# Simple installer for DeepLX CLI
# Usage: curl -sSL https://raw.githubusercontent.com/juan-de-costa-rica/deeplx-cli/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# GitHub repository
REPO="juan-de-costa-rica/deeplx-cli"
BINARY_NAME="translate"

print_header() {
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════╗"
    echo "║           DeepLX CLI Installer       ║"
    echo "╚══════════════════════════════════════╝"
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

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) 
            print_error "Unsupported architecture: $arch"
            echo "Supported: x86_64, aarch64/arm64"
            exit 1
            ;;
    esac
}

# Detect OS
detect_os() {
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case $os in
        linux) echo "linux" ;;
        darwin) echo "darwin" ;;
        *)
            print_error "Unsupported OS: $os"
            echo "Supported: Linux, macOS"
            exit 1
            ;;
    esac
}

# Get latest release version
get_latest_version() {
    print_step "Getting latest version..."
    
    local version
    version=$(curl -sSL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | cut -d'"' -f4 2>/dev/null || echo "")
    
    if [ -z "$version" ]; then
        print_error "Could not determine latest version"
        exit 1
    fi
    
    print_info "Latest version: $version"
    echo "$version"
}

# Download and install binary
install_binary() {
    local version="$1"
    local os="$2" 
    local arch="$3"
    
    print_step "Installing DeepLX CLI..."
    
    # Create temp directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT
    
    # Download URL
    local binary_name="${BINARY_NAME}-${os}-${arch}"
    if [ "$os" = "windows" ]; then
        binary_name="${binary_name}.exe"
    fi
    
    local download_url="https://github.com/$REPO/releases/download/$version/$binary_name"
    print_info "Downloading from: $download_url"
    
    # Download binary
    if ! curl -sSL "$download_url" -o "$tmp_dir/$BINARY_NAME"; then
        print_error "Failed to download binary"
        print_info "Check if the release exists at: https://github.com/$REPO/releases"
        exit 1
    fi
    
    # Make executable
    chmod +x "$tmp_dir/$BINARY_NAME"
    
    # Install to system
    local install_dir="/usr/local/bin"
    if [ -w "$install_dir" ]; then
        mv "$tmp_dir/$BINARY_NAME" "$install_dir/$BINARY_NAME"
        print_success "Installed to $install_dir/$BINARY_NAME"
    else
        print_info "Installing to $install_dir (requires sudo)..."
        sudo mv "$tmp_dir/$BINARY_NAME" "$install_dir/$BINARY_NAME"
        print_success "Installed to $install_dir/$BINARY_NAME"
    fi
}

# Verify installation
verify_installation() {
    print_step "Verifying installation..."
    
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        local version
        version=$($BINARY_NAME --version 2>/dev/null || echo "unknown")
        print_success "Installation successful! Version: $version"
        return 0
    else
        print_error "Installation failed - binary not found in PATH"
        return 1
    fi
}

# Show usage instructions
show_usage() {
    echo
    echo -e "${BOLD}🚀 Quick Start:${NC}"
    echo
    echo -e "${YELLOW}# Set up your DeepLX server token${NC}"
    echo -e "export TOKEN=your_deeplx_server_token"
    echo
    echo -e "${YELLOW}# Translate text${NC}"
    echo -e "translate \"Hello, world!\""
    echo
    echo -e "${YELLOW}# Translate to Spanish${NC}"
    echo -e "translate -t es \"Hello, how are you?\""
    echo
    echo -e "${YELLOW}# Show alternatives${NC}"
    echo -e "translate --alternatives \"Hello, world!\""
    echo
    echo -e "${YELLOW}# Configure defaults${NC}"
    echo -e "translate config set --url http://localhost:1188 --token your_token"
    echo
    echo -e "${YELLOW}# Get help${NC}"
    echo -e "translate --help"
    echo
    echo -e "${BOLD}📚 More info:${NC} https://github.com/$REPO"
}

# Main installation function
main() {
    print_header
    
    # Check dependencies
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    # Detect system
    local os arch version
    os=$(detect_os)
    arch=$(detect_arch)
    version=$(get_latest_version)
    
    print_info "System: $os-$arch"
    
    # Install
    install_binary "$version" "$os" "$arch"
    
    # Verify
    if verify_installation; then
        show_usage
    else
        exit 1
    fi
}

# Run main function
main "$@"
