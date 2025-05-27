#!/bin/bash

# easy-install.sh - One-click installer for DeepLX CLI
# This script automatically installs both the DeepLX server and the CLI client

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print messages
print_logo() {
  echo -e "${BLUE}${BOLD}"
  echo "  _____                 _   __   __    ____ _     ___ "
  echo " |  _  \\___ ___ _ __ | | _\\ \\ / /   / ___| |   |_ _|"
  echo " | | | / _ / _ \\ '_ \\| |/ /\\ V /   | |   | |    | | "
  echo " | |/ /  __/ __/ |_) |   < /   \\   | |___| |___ | | "
  echo " |___/ \\___|\\___| .__/|_|\\_\\/_/\\_\\   \\____|_____|___|"
  echo "                |_|                                    "
  echo -e "${NC}"
  echo -e "${BOLD}Simple translation for your terminal${NC}"
  echo
}

print_step() {
  echo -e "${GREEN}==>${NC} ${BOLD}$1${NC}"
}

print_info() {
  echo -e "    ${BLUE}Info:${NC} $1"
}

print_warning() {
  echo -e "    ${YELLOW}Warning:${NC} $1"
}

print_error() {
  echo -e "    ${RED}Error:${NC} $1"
}

# Check if running with sudo
check_sudo() {
  if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root is not recommended."
    print_info "The installer will prompt for sudo access when needed."
    
    # If the script was run with sudo, re-run it as the original user
    if [ -n "$SUDO_USER" ]; then
      print_info "Re-running installer as $SUDO_USER..."
      exec su - "$SUDO_USER" -c "bash $0"
      exit
    fi
  fi
}

# Check for dependencies
check_dependencies() {
  print_step "Checking dependencies"
  
  # Check for curl
  if ! command -v curl &> /dev/null; then
    print_error "curl is required but not installed."
    print_info "Please install curl and try again."
    exit 1
  fi
  
  # Check for Docker
  if command -v docker &> /dev/null; then
    print_info "Docker is installed, will use it for DeepLX server"
    HAS_DOCKER=true
  else
    print_warning "Docker is not installed."
    print_info "Will download DeepLX binary instead of using Docker."
    HAS_DOCKER=false
  fi
  
  # Check for Go (optional)
  if command -v go &> /dev/null; then
    GO_VERSION=$(go version | awk '{print $3}')
    print_info "Go $GO_VERSION is installed, will build CLI from source"
    HAS_GO=true
  else
    print_info "Go is not installed, will download pre-built CLI binary"
    HAS_GO=false
  fi
}

# Create directories
setup_directories() {
  print_step "Setting up directories"
  
  # Create config directory
  DEEPLX_CONFIG_DIR="$HOME/.config/deeplx"
  mkdir -p "$DEEPLX_CONFIG_DIR"
  print_info "Created config directory: $DEEPLX_CONFIG_DIR"
  
  # Create bin directory if it doesn't exist
  DEEPLX_BIN_DIR="$HOME/.local/bin"
  mkdir -p "$DEEPLX_BIN_DIR"
  print_info "Created bin directory: $DEEPLX_BIN_DIR"
  
  # Add bin directory to PATH if not already there
  if [[ ":$PATH:" != *":$DEEPLX_BIN_DIR:"* ]]; then
    print_info "Adding $DEEPLX_BIN_DIR to PATH"
    
    # Determine shell profile file
    SHELL_PROFILE=""
    if [ -n "$BASH_VERSION" ]; then
      if [ -f "$HOME/.bashrc" ]; then
        SHELL_PROFILE="$HOME/.bashrc"
      elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
      fi
    elif [ -n "$ZSH_VERSION" ]; then
      SHELL_PROFILE="$HOME/.zshrc"
    fi
    
    if [ -n "$SHELL_PROFILE" ]; then
      echo "export PATH=\"\$PATH:$DEEPLX_BIN_DIR\"" >> "$SHELL_PROFILE"
      print_info "Added $DEEPLX_BIN_DIR to PATH in $SHELL_PROFILE"
      print_info "Please run 'source $SHELL_PROFILE' or start a new terminal after installation"
    else
      print_warning "Could not determine shell profile file."
      print_info "Please add $DEEPLX_BIN_DIR to your PATH manually"
    fi
  fi
}

# Download the CLI binary
download_cli() {
  print_step "Downloading DeepLX CLI"
  
  # Determine system architecture
  ARCH=$(uname -m)
  case $ARCH in
    x86_64)
      ARCH="amd64"
      ;;
    aarch64|arm64)
      ARCH="arm64"
      ;;
    *)
      print_error "Unsupported architecture: $ARCH"
      print_info "Please build from source: https://github.com/yourusername/deeplx-cli"
      exit 1
      ;;
  esac
  
  # Determine system OS
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  case $OS in
    linux)
      OS="linux"
      ;;
    darwin)
      OS="darwin"
      ;;
    *)
      print_error "Unsupported operating system: $OS"
      print_info "Please build from source: https://github.com/yourusername/deeplx-cli"
      exit 1
      ;;
  esac
  
  # GitHub release URL
  GITHUB_REPO="juan-de-costa-rica/deeplx-cli"
  GITHUB_API_URL="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
  
  print_info "Detecting latest version..."
  
  # Get the latest release version
  if ! RELEASE_INFO=$(curl -s $GITHUB_API_URL); then
    print_error "Failed to get latest release information."
    print_info "Using default version: v0.1.0"
    VERSION="0.1.0"
  else
    VERSION=$(echo $RELEASE_INFO | grep -o '"tag_name": *"[^"]*"' | awk -F'"' '{print $4}' | sed 's/^v//')
    if [ -z "$VERSION" ]; then
      print_warning "Could not determine latest version."
      print_info "Using default version: v0.1.0"
      VERSION="0.1.0"
    else
      print_info "Latest version: v$VERSION"
    fi
  fi
  
  # Binary name
  BINARY_NAME="translate-$OS-$ARCH"
  if [ "$OS" = "windows" ]; then
    BINARY_NAME="$BINARY_NAME.exe"
  fi
  
  # Download URL
  DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/v$VERSION/$BINARY_NAME"
  
  # Download the binary
  print_info "Downloading from: $DOWNLOAD_URL"
  if ! curl -L -o "$DEEPLX_BIN_DIR/translate" "$DOWNLOAD_URL"; then
    print_error "Failed to download CLI binary."
    print_info "Please check your internet connection and try again."
    exit 1
  fi
  
  # Make binary executable
  chmod +x "$DEEPLX_BIN_DIR/translate"
  print_info "CLI binary installed to: $DEEPLX_BIN_DIR/translate"
}

# Build the CLI from source
build_cli() {
  print_step "Building DeepLX CLI from source"
  
  # Create temporary directory
  TEMP_DIR=$(mktemp -d)
  print_info "Created temporary directory: $TEMP_DIR"
  
  # Clone the repository
  print_info "Cloning repository..."
  if ! git clone https://github.com/juan-de-costa-rica/deeplx-cli.git "$TEMP_DIR"; then
    print_error "Failed to clone repository."
    print_info "Falling back to pre-built binary..."
    download_cli
    return
  fi
  
  # Build the binary
  print_info "Building CLI..."
  cd "$TEMP_DIR"
  if ! go build -o translate; then
    print_error "Failed to build CLI."
    print_info "Falling back to pre-built binary..."
    download_cli
    return
  fi
  
  # Copy binary to bin directory
  cp translate "$DEEPLX_BIN_DIR/translate"
  chmod +x "$DEEPLX_BIN_DIR/translate"
  print_info "CLI binary installed to: $DEEPLX_BIN_DIR/translate"
  
  # Clean up
  cd - > /dev/null
  rm -rf "$TEMP_DIR"
}

# Setup the DeepLX server with Docker
setup_docker_server() {
  print_step "Setting up DeepLX server with Docker"
  
  # Check if container already exists
  if docker ps -a | grep -q "deeplx"; then
    print_info "DeepLX server container already exists."
    
    # Check if container is running
    if docker ps | grep -q "deeplx"; then
      print_info "DeepLX server is already running."
    else
      print_info "Starting DeepLX server..."
      docker start deeplx
    fi
  else
    print_info "Creating and starting DeepLX server container..."
    docker run -d --name deeplx --restart unless-stopped -p 1188:1188 ghcr.io/owo-network/deeplx:latest
  fi
  
  # Check if container is running
  if docker ps | grep -q "deeplx"; then
    print_info "DeepLX server is running at: http://localhost:1188"
    
    # Save server URL to config
    echo "DEEPLX_SERVER_URL=http://localhost:1188" > "$DEEPLX_CONFIG_DIR/config"
  else
    print_error "Failed to start DeepLX server container."
    print_info "Please start it manually with: docker start deeplx"
    
    # Save default server URL to config
    echo "DEEPLX_SERVER_URL=http://localhost:1188" > "$DEEPLX_CONFIG_DIR/config"
  fi
}

# Download and setup the DeepLX server binary
setup_binary_server() {
  print_step "Setting up DeepLX server binary"
  
  # Determine system architecture
  ARCH=$(uname -m)
  case $ARCH in
    x86_64)
      ARCH="amd64"
      ;;
    aarch64|arm64)
      ARCH="arm64"
      ;;
    *)
      print_error "Unsupported architecture for server binary: $ARCH"
      print_info "Using public DeepLX server instead."
      echo "DEEPLX_SERVER_URL=https://deeplx.example.com" > "$DEEPLX_CONFIG_DIR/config"
      return
      ;;
  esac
  
  # Determine system OS
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  case $OS in
    linux)
      OS="linux"
      ;;
    darwin)
      OS="darwin"
      ;;
    *)
      print_error "Unsupported operating system for server binary: $OS"
      print_info "Using public DeepLX server instead."
      echo "DEEPLX_SERVER_URL=https://deeplx.example.com" > "$DEEPLX_CONFIG_DIR/config"
      return
      ;;
  esac
  
  # Download URL for DeepLX server binary
  DEEPLX_SERVER_URL="https://github.com/OwO-Network/DeepLX/releases/latest/download/deeplx_${OS}_${ARCH}"
  
  # Download the binary
  print_info "Downloading DeepLX server from: $DEEPLX_SERVER_URL"
  if ! curl -L -o "$DEEPLX_CONFIG_DIR/deeplx" "$DEEPLX_SERVER_URL"; then
    print_error "Failed to download DeepLX server binary."
    print_info "Using public DeepLX server instead."
    echo "DEEPLX_SERVER_URL=https://deeplx.example.com" > "$DEEPLX_CONFIG_DIR/config"
    return
  fi
  
  # Make binary executable
  chmod +x "$DEEPLX_CONFIG_DIR/deeplx"
  
  # Create systemd service file if on Linux
  if [ "$OS" = "linux" ]; then
    print_info "Creating systemd service..."
    
    # Create service file
    cat << EOF > /tmp/deeplx.service
[Unit]
Description=DeepLX Translation Service
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=$DEEPLX_CONFIG_DIR/deeplx
User=$USER

[Install]
WantedBy=multi-user.target
EOF
    
    # Install service file
    print_info "Installing systemd service (requires sudo)..."
    if sudo mv /tmp/deeplx.service /etc/systemd/system/deeplx.service; then
      sudo systemctl daemon-reload
      sudo systemctl enable deeplx
      sudo systemctl start deeplx
      
      # Check if service is running
      if systemctl is-active --quiet deeplx; then
        print_info "DeepLX server is running as a systemd service."
      else
        print_warning "Failed to start DeepLX server service."
        print_info "Please start it manually with: systemctl start deeplx"
      fi
    else
      print_warning "Failed to install systemd service."
      print_info "You can start the server manually with: $DEEPLX_CONFIG_DIR/deeplx"
    fi
  elif [ "$OS" = "darwin" ]; then
    # Create launchd service file
    print_info "Creating launchd service..."
    
    # Create service file
    cat << EOF > "$HOME/Library/LaunchAgents/me.missuo.deeplx.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>me.missuo.deeplx</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DEEPLX_CONFIG_DIR/deeplx</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
    
    # Load service
    launchctl load "$HOME/Library/LaunchAgents/me.missuo.deeplx.plist"
    
    print_info "DeepLX server is running as a launchd service."
  else
    print_warning "Automatic service setup not supported on this platform."
    print_info "You can start the server manually with: $DEEPLX_CONFIG_DIR/deeplx"
  fi
  
  # Save server URL to config
  echo "DEEPLX_SERVER_URL=http://localhost:1188" > "$DEEPLX_CONFIG_DIR/config"
}

# Test the installation
test_installation() {
  print_step "Testing installation"
  
  # Test CLI
  if [ -x "$DEEPLX_BIN_DIR/translate" ]; then
    print_info "Testing CLI version..."
    if "$DEEPLX_BIN_DIR/translate" --version; then
      print_info "CLI test successful!"
    else
      print_warning "CLI test failed."
      print_info "Please check the installation manually."
    fi
  else
    print_error "CLI binary not found or not executable."
    print_info "Please check the installation manually."
    return
  fi
  
  # Test translation
  print_info "Testing translation..."
  if "$DEEPLX_BIN_DIR/translate" -t es "Hello"; then
    print_info "Translation test successful!"
  else
    print_warning "Translation test failed."
    print_info "Please check that the DeepLX server is running."
  fi
}

# Print success message
print_success() {
  echo
  echo -e "${GREEN}${BOLD}Installation complete!${NC}"
  echo
  echo -e "You can now use the ${BOLD}translate${NC} command to translate text."
  echo
  echo -e "Example usage:"
  echo -e "  ${BOLD}translate${NC} \"Hello, world!\"                   # Translate to English (default)"
  echo -e "  ${BOLD}translate${NC} -t es \"Hello, how are you?\"       # Translate to Spanish"
  echo -e "  ${BOLD}translate${NC} -s fr -t en \"Bonjour le monde!\"   # French to English"
  echo -e "  ${BOLD}translate${NC} -a -t de \"Hello world\"            # Show alternatives"
  echo
  echo -e "For more options, run: ${BOLD}translate --help${NC}"
  echo
  
  # Remind about PATH if needed
  if [[ ":$PATH:" != *":$DEEPLX_BIN_DIR:"* ]]; then
    echo -e "${YELLOW}Important:${NC} You need to add ${BOLD}$DEEPLX_BIN_DIR${NC} to your PATH."
    echo -e "You can do this by running:"
    echo -e "  ${BOLD}export PATH=\"\$PATH:$DEEPLX_BIN_DIR\"${NC}"
    echo -e "Or starting a new terminal session."
    echo
  fi
}

# Main installation function
main() {
  # Print logo
  print_logo
  
  # Check if running with sudo
  check_sudo
  
  # Check dependencies
  check_dependencies
  
  # Setup directories
  setup_directories
  
  # Install CLI
  if [ "$HAS_GO" = true ]; then
    build_cli
  else
    download_cli
  fi
  
  # Setup server
  if [ "$HAS_DOCKER" = true ]; then
    setup_docker_server
  else
    setup_binary_server
  fi
  
  # Test installation
  test_installation
  
  # Print success message
  print_success
}

# Run main function
main
