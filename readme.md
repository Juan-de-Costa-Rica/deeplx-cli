# DeepLX CLI

A simple command-line interface for translating text using DeepLX servers.

## 🚀 Quick Install

### One-liner (Linux/macOS)
```bash
curl -sSL https://raw.githubusercontent.com/juan-de-costa-rica/deeplx-cli/main/install.sh | bash
```

### Manual Install
Download the appropriate binary from [releases](https://github.com/juan-de-costa-rica/deeplx-cli/releases/latest):

```bash
# Linux AMD64
curl -L -o translate https://github.com/juan-de-costa-rica/deeplx-cli/releases/latest/download/translate-linux-amd64
chmod +x translate
sudo mv translate /usr/local/bin/

# macOS ARM64 (Apple Silicon)
curl -L -o translate https://github.com/juan-de-costa-rica/deeplx-cli/releases/latest/download/translate-darwin-arm64
chmod +x translate
sudo mv translate /usr/local/bin/
```

## 🔧 Setup

### Configure Authentication
```bash
# Option 1: Environment variable
export TOKEN=your_deeplx_server_token

# Option 2: Save configuration
translate config set --url http://localhost:1188 --token your_token
```

## 📝 Usage

### Basic Translation
```bash
# Auto-detect source language, translate to English
translate "Hola mundo"

# Specify target language
translate -t es "Hello world"

# Specify both source and target
translate -s en -t fr "Hello world"
```

### Advanced Options
```bash
# Show alternative translations
translate --alternatives "Hello world"

# Use custom server URL
translate --url http://my-server:1188 "Hello world"

# Debug mode
translate --debug "Hello world"

# Custom timeout
translate --timeout 60 "Hello world"
```

### Configuration Management
```bash
# Set default server and token
translate config set --url http://localhost:1188 --token your_token

# Show current configuration
translate config show
```

## 🔗 DeepLX Server

This CLI requires a DeepLX server. You can:

1. **Run your own server**: https://github.com/OwO-Network/DeepLX
2. **Use Docker**: `docker run -p 1188:1188 ghcr.io/owo-network/deeplx:latest`

## 📖 Examples

```bash
# Quick translation
translate "How are you today?"

# Business translation to Spanish
translate -t es "Please review the quarterly report"

# Get multiple alternatives
translate --alternatives -t de "Good morning"

# Translate with debugging info
translate --debug -t ja "Thank you very much"
```

## 🛠 Development

```bash
# Clone and build
git clone https://github.com/juan-de-costa-rica/deeplx-cli.git
cd deeplx-cli
go build -o translate .

# Run tests
go test -v ./...
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.maybe it works now

