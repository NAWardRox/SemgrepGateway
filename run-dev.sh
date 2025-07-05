#!/bin/bash
set -e

echo "🚀 Starting development server..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if virtual environment exists and activate it
if [ -d "venv" ] && [ -f "venv/bin/activate" ]; then
    echo -e "${GREEN}🔌 Activating virtual environment...${NC}"
    source venv/bin/activate
    PYTHON_CMD="python"
    PIP_CMD="pip"
elif [ -d "venv" ] && [ -f "venv/Scripts/activate" ]; then
    # Windows-style venv
    echo -e "${GREEN}🔌 Activating virtual environment (Windows)...${NC}"
    source venv/Scripts/activate
    PYTHON_CMD="python"
    PIP_CMD="pip"
else
    echo -e "${YELLOW}⚠️ Virtual environment not found, using global Python...${NC}"
    PYTHON_CMD="python3"
    PIP_CMD="python3 -m pip"
fi

# Check if dependencies are installed
echo -e "${YELLOW}🔍 Checking dependencies...${NC}"
if ! $PYTHON_CMD -c "import fastapi, uvicorn" 2>/dev/null; then
    echo -e "${YELLOW}📦 Installing missing dependencies...${NC}"
    $PIP_CMD install -r requirements.txt
fi

# Check semgrep installation
if ! command -v semgrep &> /dev/null; then
    echo -e "${YELLOW}📦 Installing Semgrep...${NC}"
    $PIP_CMD install semgrep
fi

# Copy .env if not exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}📋 Creating .env file...${NC}"
    cp .env.example .env
fi

# Create logs directory
mkdir -p logs

# Test app import
echo -e "${YELLOW}🧪 Testing app...${NC}"
$PYTHON_CMD -c "
try:
    import sys
    sys.path.insert(0, '.')
    from app.main import app
    print('✅ App loaded successfully')
except Exception as e:
    print(f'❌ Error loading app: {e}')
    exit(1)
"

echo ""
echo -e "${GREEN}🚀 Starting Semgrep API Development Server${NC}"
echo ""
echo -e "${YELLOW}📊 Access Points:${NC}"
echo "  • API: http://localhost:8000"
echo "  • Docs: http://localhost:8000/docs"
echo "  • Health: http://localhost:8000/health"
echo ""
echo -e "${YELLOW}🛑 Stop server: Ctrl+C${NC}"
echo ""

# Start the development server
$PYTHON_CMD -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload