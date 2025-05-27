#!/bin/bash

# install.sh - Install script for DeepLX CLI
# This script installs both the DeepLX server and the CLI client

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print messages
print_message() {
  echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
  echo -e "${RED}[x]${NC} $1"
}

# Check if Docker is installed
check_docker() {
  if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    echo "You can install Docker by following the instructions at:"
    echo "https://docs.docker.com/get-docker/"
    exit 1
  fi
  print_message "Docker is installed."
}

# Start DeepLX server in Docker
start_deeplx_server() {
  print_message "Setting up DeepLX server..."
  
  # Check if container is already running
  if docker ps | grep -q "deeplx"; then
    print_message "DeepLX server is already running."
  else
    # Check if the container exists but is not running
    if docker ps -a | grep -q "deeplx"; then
      print_message "Starting existing DeepLX container..."
      docker start deeplx
    else
      print_message "Creating and starting DeepLX container..."
      docker run -d --name deeplx -p 1188:1188 ghcr.io/owo-network/deeplx:latest
    fi
  fi
  
  print_message "DeepLX server is running at http://localhost:1188"
}

# Build and install the CLI
install_cli() {
  print_message "Building and installing DeepLX CLI..."
  
  # Check if Go is installed
  if ! command -v go &> /dev/null; then
    print_error "Go is not installed. Please install Go first."
    echo "You can install Go by following the instructions at:"
    echo "https://golang.org/doc/install"
    exit 1
  fi
  
  print_message "Building the CLI..."
  go build -o translate
  
  print_message "Installing the CLI to /usr/local/bin/ (requires sudo)..."
  sudo mv translate /usr/local/bin/
  
  print_message "CLI installation complete!"
}

# Main function
main() {
  print_message "Welcome to DeepLX CLI installer!"
  
  # Ask if user wants to install server
  read -p "Do you want to install the DeepLX server using Docker? [y/N] " install_server
  if [[ $install_server =~ ^[Yy]$ ]]; then
    check_docker
    start_deeplx_server
  else
    print_warning "Skipping DeepLX server installation."
    print_warning "Make sure you have a DeepLX server running to use the CLI."
  fi
  
  # Ask if user wants to install CLI
  read -p "Do you want to build and install the DeepLX CLI? [Y/n] " install_cli_choice
  if [[ $install_cli_choice =~ ^[Nn]$ ]]; then
    print_warning "Skipping CLI installation."
  else
    install_cli
  fi
  
  print_message "Installation complete!"
  print_message "You can now use the 'translate' command to translate text."
  print_message "Example: translate -t es \"Hello, how are you?\""
}

# Run the main function
main
