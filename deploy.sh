#!/bin/bash
set -e

echo "🚀 Deploying Semgrep API..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found${NC}"
    exit 1
fi

# Choose compose file
COMPOSE_FILE="docker-compose.yml"
if [ "$1" = "prod" ]; then
    COMPOSE_FILE="docker-compose.prod.yml"
    echo -e "${YELLOW}🏭 Production deployment${NC}"
else
    echo -e "${YELLOW}🛠️ Development deployment${NC}"
fi

# Stop existing containers
echo -e "${YELLOW}🛑 Stopping existing containers...${NC}"
docker-compose -f $COMPOSE_FILE down 2>/dev/null || true

# Build and start
echo -e "${YELLOW}🔨 Building and starting containers...${NC}"
docker-compose -f $COMPOSE_FILE build
docker-compose -f $COMPOSE_FILE up -d

# Wait for services
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 20

# Health check
echo -e "${YELLOW}🔍 Checking health...${NC}"
max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Health check passed!${NC}"
        break
    else
        echo -e "${YELLOW}⏳ Attempt $attempt/$max_attempts...${NC}"
        sleep 3
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${RED}❌ Health check failed${NC}"
    docker-compose -f $COMPOSE_FILE logs
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Deployment successful!${NC}"
echo ""
echo -e "${YELLOW}🔗 Access Points:${NC}"
echo "• API: http://localhost:8000"
echo "• Docs: http://localhost:8000/docs"
echo "• Health: http://localhost:8000/health"
echo ""
echo -e "${YELLOW}📋 Useful Commands:${NC}"
echo "• Logs: docker-compose -f $COMPOSE_FILE logs -f"
echo "• Stop: docker-compose -f $COMPOSE_FILE down"
echo "• Test: ./test.sh"