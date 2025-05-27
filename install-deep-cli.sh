#!/bin/bash
# ╔════════════════════════════════════════════════════════════════╗
# ║            DeepL Translate CLI - One-Click Installer           ║
# ╚════════════════════════════════════════════════════════════════╝

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
CLI_NAME="deepl-translate"
INSTALL_DIR="/usr/local/bin"
REPO_URL="https://raw.githubusercontent.com/your-username/deepl-cli/main"
CONFIG_DIR="$HOME/.config/deepl-translate"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Check if terminal supports unicode box drawing
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  USE_UNICODE=true
else
  USE_UNICODE=false
fi

# Print functions
print_header() {
  local title="$1"
  
  if [ "$USE_UNICODE" = true ]; then
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                DeepL Translate CLI - Installer                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
  else
    echo -e "${BLUE}${BOLD}"
    echo "+---------------------------------------------------------+"
    echo "|              DeepL Translate CLI - Installer            |"
    echo "+---------------------------------------------------------+"
    echo -e "${NC}"
  fi
}

print_step() {
  if [ "$USE_UNICODE" = true ]; then
    echo -e "${CYAN}${BOLD}→${NC} ${BOLD}$1${NC}"
  else
    echo -e "${CYAN}${BOLD}>>${NC} ${BOLD}$1${NC}"
  fi
}

print_info() {
  if [ "$USE_UNICODE" = true ]; then
    echo -e "  ${BLUE}ℹ${NC} $1"
  else
    echo -e "  ${BLUE}INFO:${NC} $1"
  fi
}

print_success() {
  if [ "$USE_UNICODE" = true ]; then
    echo -e "${GREEN}${BOLD}✓${NC} ${BOLD}$1${NC}"
  else
    echo -e "${GREEN}${BOLD}SUCCESS:${NC} ${BOLD}$1${NC}"
  fi
}

print_error() {
  if [ "$USE_UNICODE" = true ]; then
    echo -e "${RED}${BOLD}✗ Error:${NC} $1" >&2
  else
    echo -e "${RED}${BOLD}ERROR:${NC} $1" >&2
  fi
}

print_warning() {
  if [ "$USE_UNICODE" = true ]; then
    echo -e "${YELLOW}${BOLD}⚠ Warning:${NC} $1"
  else
    echo -e "${YELLOW}${BOLD}WARNING:${NC} $1"
  fi
}

# Main installation function
main() {
  print_header
  
  # Check for curl
  if ! command -v curl >/dev/null 2>&1; then
    print_error "curl is required but not installed. Please install curl and try again."
    exit 1
  fi
  
  # Check if script is already installed
  if command -v "$CLI_NAME" >/dev/null 2>&1; then
    current_path=$(which "$CLI_NAME")
    print_warning "DeepL Translate CLI is already installed at: $current_path"
    
    # Ask for reinstallation
    read -p "Do you want to reinstall? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_info "Skipping installation."
      
      # If config exists, ask about reconfiguring
      if [ -f "$CONFIG_FILE" ]; then
        read -p "Do you want to reconfigure your API key? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          configure_api_key
        fi
      else
        # If no config exists, offer to configure
        read -p "No configuration found. Would you like to set up your DeepL API key? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
          configure_api_key
        fi
      fi
      
      print_usage
      exit 0
    fi
  fi
  
  # Download the script
  print_step "Downloading DeepL Translate CLI..."
  
  if [ "$USE_UNICODE" = true ]; then
    echo -n "  "
  fi
  
  # Create a temporary file
  tmp_file=$(mktemp)
  
  if ! curl -Ss "$REPO_URL/deepl-translate" -o "$tmp_file"; then
    print_error "Failed to download the script. Please check your internet connection."
    rm -f "$tmp_file"
    exit 1
  fi
  
  print_info "Download successful!"
  
  # Make the script executable
  chmod +x "$tmp_file"
  
  # Install to the system
  print_step "Installing to $INSTALL_DIR..."
  
  # Check if we can write to the install directory
  if [ -w "$INSTALL_DIR" ]; then
    mv "$tmp_file" "$INSTALL_DIR/$CLI_NAME"
  else
    print_info "Administrator privileges required for installation."
    echo -n "  "
    
    if ! sudo mv "$tmp_file" "$INSTALL_DIR/$CLI_NAME"; then
      print_error "Failed to install the script. Please make sure you have sudo privileges."
      rm -f "$tmp_file"
      exit 1
    fi
  fi
  
  # Verify installation
  if ! command -v "$CLI_NAME" >/dev/null 2>&1; then
    print_error "Installation verification failed. The script may not be in your PATH."
    print_info "Manual installation: you can copy $tmp_file to a directory in your PATH."
    exit 1
  fi
  
  print_success "DeepL Translate CLI has been successfully installed!"
  
  # Configure API key if needed
  echo
  read -p "Would you like to configure your DeepL API key now? [Y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    configure_api_key
  else
    print_info "You can configure your API key later by running: $CLI_NAME --config"
  fi
  
  echo
  print_usage
}

# Configure API key
configure_api_key() {
  echo
  print_step "Configuring DeepL API key..."
  
  # Check if config directory exists
  if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
  fi
  
  # Ask for API key
  echo -e "${BOLD}Enter your DeepL API key:${NC}"
  echo -e "  ${YELLOW}(You can find or create your API key at https://www.deepl.com/account/summary)${NC}"
  read -p "> " api_key
  
  if [ -z "$api_key" ]; then
    print_error "No API key provided. Configuration cancelled."
    return 1
  fi
  
  # Determine if it's a free or pro key
  local api_url
  if [[ "$api_key" == *":fx"* ]]; then
    api_url="https://api-free.deepl.com/v2"
    print_info "Detected Free API key"
  else
    api_url="https://api.deepl.com/v2"
    print_info "Detected Pro API key"
  fi
  
  # Save to config file
  echo "{\"api_key\": \"$api_key\", \"api_url\": \"$api_url\"}" > "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"  # Secure the file
  
  print_success "API key configuration saved to $CONFIG_FILE"
  
  # Test the configuration
  print_step "Testing API connection..."
  
  # Make a simple API request to test the key
  local response
  response=$(curl -s -X GET "$api_url/languages?type=source" \
    -H "Authorization: DeepL-Auth-Key $api_key")
  
  # Check for errors
  if echo "$response" | grep -q "\"message\""; then
    error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    print_error "API test failed: $error_msg"
    print_warning "You may need to check your API key or connection. You can reconfigure later with: $CLI_NAME --config"
    return 1
  fi
  
  # Check if response looks like a language list
  if ! echo "$response" | grep -q "\"language\""; then
    print_error "API test failed: Unexpected response format"
    print_warning "You may need to check your API key or connection. You can reconfigure later with: $CLI_NAME --config"
    return 1
  fi
  
  print_success "API connection test successful!"
  return 0
}

# Print usage information
print_usage() {
  echo
  echo -e "${BOLD}${GREEN}🚀 Quick Start Guide:${NC}"
  echo
  
  echo -e "${YELLOW}# Basic translation (auto-detect to English)${NC}"
  echo -e "$CLI_NAME \"Hello, world!\""
  echo
  
  echo -e "${YELLOW}# Translate to German${NC}"
  echo -e "$CLI_NAME -t DE \"Hello, world!\""
  echo
  
  echo -e "${YELLOW}# Translate with specific source language${NC}"
  echo -e "$CLI_NAME -s EN -t ES \"Hello, world!\""
  echo
  
  echo -e "${YELLOW}# Use formal language${NC}"
  echo -e "$CLI_NAME -t DE -f more \"Hello, world!\""
  echo
  
  echo -e "${YELLOW}# Show alternative translations${NC}"
  echo -e "$CLI_NAME --alternatives \"Hello, world!\""
  echo
  
  echo -e "${YELLOW}# List available languages${NC}"
  echo -e "$CLI_NAME --list-languages"
  echo
  
  echo -e "${YELLOW}# Get help${NC}"
  echo -e "$CLI_NAME --help"
  echo
  
  echo -e "${BOLD}${BLUE}Need help?${NC}"
  echo "For more information, run: $CLI_NAME --help"
}

# Run the main installation function
main "$@"
