#!/bin/bash
set -e
echo "🚀 Setting up Semgrep API..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Setup complete! Run: docker-compose up -d"