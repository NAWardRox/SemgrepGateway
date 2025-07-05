#!/bin/bash
set -e

echo "🚀 Setting up Semgrep API project..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 required${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Python3 found${NC}"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}📦 Creating virtual environment...${NC}"
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
echo -e "${YELLOW}⬆️ Upgrading pip...${NC}"
pip install --upgrade pip

# Install dependencies
echo -e "${YELLOW}📥 Installing dependencies...${NC}"
pip install -r requirements.txt

# Copy environment file
if [ ! -f .env ]; then
    echo -e "${YELLOW}📋 Creating .env file...${NC}"
    cp .env.example .env

    # Generate secret key
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    sed -i "s/your-secret-key-change-in-production-minimum-32-chars/$SECRET_KEY/g" .env
fi

# Create logs directory
mkdir -p logs

# Test installation
echo -e "${YELLOW}🧪 Testing installation...${NC}"
python3 -c "
try:
    import app.main
    print('✅ App imports successfully')
except ImportError as e:
    print(f'❌ Import error: {e}')
    exit(1)
"

echo ""
echo -e "${GREEN}🎉 Setup completed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Development: ./run-dev.sh"
echo "2. Docker: ./deploy.sh"
echo "3. Test: ./test.sh"