#!/bin/bash

# install-online.sh - Simple online installer for DeepLX CLI
# This script downloads and runs the full installer

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Display banner
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

# Check for curl
if ! command -v curl &> /dev/null; then
    echo "Error: curl is required but not installed."
    echo "Please install curl and try again."
    exit 1
fi

# Download and run the installer
echo -e "${GREEN}${BOLD}Downloading and running installer...${NC}"
curl -fsSL https://raw.githubusercontent.com/juan-de-costa-rica/deeplx-cli/main/easy-install.sh -o /tmp/deeplx-easy-install.sh
chmod +x /tmp/deeplx-easy-install.sh
bash /tmp/deeplx-easy-install.sh
rm /tmp/deeplx-easy-install.sh
