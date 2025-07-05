#!/bin/bash
set -e

echo "🚀 Starting development server..."

# Activate virtual environment if exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Install dependencies if needed
if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "📦 Installing dependencies..."
    pip install -r requirements.txt
fi

# Copy .env if not exists
if [ ! -f ".env" ]; then
    cp .env.example .env
fi

# Create logs directory
mkdir -p logs

echo "📊 Starting at: http://localhost:8000"
echo "📚 Docs at: http://localhost:8000/docs"
echo "🛑 Stop with: Ctrl+C"

# Run development server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload