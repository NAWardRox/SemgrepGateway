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
    echo -e "${RED}❌ Python3 required but not found${NC}"
    echo "Please install Python3 first:"
    echo "  Ubuntu/Debian: sudo apt install python3 python3-venv python3-pip"
    echo "  CentOS/RHEL: sudo yum install python3 python3-pip"
    echo "  macOS: brew install python3"
    exit 1
fi

echo -e "${GREEN}✅ Python3 found: $(python3 --version)${NC}"

# Check if we can create virtual environment
if ! python3 -m venv --help &> /dev/null; then
    echo -e "${RED}❌ python3-venv not available${NC}"
    echo "Installing python3-venv..."

    # Try to install venv module
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y python3-venv
    elif command -v yum &> /dev/null; then
        sudo yum install -y python3-venv
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3-venv
    else
        echo "Please install python3-venv manually for your system"
        exit 1
    fi
fi

# Remove existing venv if corrupted
if [ -d "venv" ] && [ ! -f "venv/bin/activate" ]; then
    echo -e "${YELLOW}🔄 Removing corrupted virtual environment...${NC}"
    rm -rf venv
fi

# Create virtual environment if not exists
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}📦 Creating virtual environment...${NC}"
    python3 -m venv venv

    # Verify creation
    if [ ! -f "venv/bin/activate" ]; then
        echo -e "${RED}❌ Failed to create virtual environment${NC}"
        echo "Trying alternative method..."

        # Try with virtualenv if available
        if command -v virtualenv &> /dev/null; then
            virtualenv venv
        else
            echo "Installing virtualenv..."
            python3 -m pip install --user virtualenv
            python3 -m virtualenv venv
        fi
    fi
fi

# Verify venv exists
if [ ! -f "venv/bin/activate" ]; then
    echo -e "${RED}❌ Virtual environment creation failed${NC}"
    echo "Continuing with global Python installation..."
    USE_GLOBAL_PYTHON=true
else
    echo -e "${GREEN}✅ Virtual environment created${NC}"
    USE_GLOBAL_PYTHON=false
fi

# Activate virtual environment if available
if [ "$USE_GLOBAL_PYTHON" = false ]; then
    echo -e "${YELLOW}🔌 Activating virtual environment...${NC}"
    source venv/bin/activate

    # Upgrade pip in venv
    echo -e "${YELLOW}⬆️ Upgrading pip...${NC}"
    python -m pip install --upgrade pip
else
    echo -e "${YELLOW}⚠️ Using global Python installation${NC}"
    # Try to upgrade global pip if possible
    python3 -m pip install --user --upgrade pip 2>/dev/null || echo "Could not upgrade pip"
fi

# Install dependencies
echo -e "${YELLOW}📥 Installing dependencies...${NC}"
if [ "$USE_GLOBAL_PYTHON" = false ]; then
    pip install -r requirements.txt
else
    python3 -m pip install --user -r requirements.txt
fi

# Copy environment file
if [ ! -f .env ]; then
    echo -e "${YELLOW}📋 Creating .env file...${NC}"
    cp .env.example .env

    # Generate secret key
    echo -e "${YELLOW}🔐 Generating secret key...${NC}"
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

    # Replace secret key in .env file
    if command -v sed &> /dev/null; then
        sed -i.bak "s/your-secret-key-change-in-production-minimum-32-chars/$SECRET_KEY/g" .env
        rm -f .env.bak
    else
        echo "SECRET_KEY=$SECRET_KEY" >> .env
    fi

    echo -e "${GREEN}✅ Environment file created with secure secret key${NC}"
else
    echo -e "${GREEN}✅ Environment file already exists${NC}"
fi

# Create logs directory
echo -e "${YELLOW}📁 Creating directories...${NC}"
mkdir -p logs

# Test installation
echo -e "${YELLOW}🧪 Testing installation...${NC}"
if [ "$USE_GLOBAL_PYTHON" = false ]; then
    python -c "
try:
    import app.main
    print('✅ App imports successfully')
except ImportError as e:
    print(f'❌ Import error: {e}')
    print('Try running: pip install -r requirements.txt')
    exit(1)
except Exception as e:
    print(f'⚠️ Warning: {e}')
"
else
    python3 -c "
try:
    import sys
    sys.path.insert(0, '.')
    import app.main
    print('✅ App imports successfully')
except ImportError as e:
    print(f'❌ Import error: {e}')
    print('Try running: python3 -m pip install --user -r requirements.txt')
    exit(1)
except Exception as e:
    print(f'⚠️ Warning: {e}')
"
fi

# Make other scripts executable
chmod +x *.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}🎉 Setup completed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
if [ "$USE_GLOBAL_PYTHON" = false ]; then
    echo "1. Activate venv: source venv/bin/activate"
    echo "2. Development: ./run-dev.sh"
else
    echo "1. Development: ./run-dev.sh"
fi
echo "3. Docker: ./deploy.sh"
echo "4. Test: ./test.sh"
echo ""
echo -e "${YELLOW}Quick start:${NC}"
echo "  ./run-dev.sh    # Local development"
echo "  ./deploy.sh     # Docker deployment"