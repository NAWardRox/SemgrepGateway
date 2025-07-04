#!/bin/bash
set -e

echo "🚀 Deploying Semgrep API..."

# Build and start
docker-compose down 2>/dev/null || true
docker-compose build --no-cache
docker-compose up -d

# Wait and test
echo "⏳ Waiting for service..."
sleep 10

if curl -f http://localhost:8000/health >/dev/null 2>&1; then
    echo "✅ Deployed successfully!"
    echo "📊 API: http://localhost:8000"
    echo "📚 Docs: http://localhost:8000/docs"
else
    echo "❌ Health check failed"
    docker-compose logs
    exit 1
fi