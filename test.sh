#!/bin/bash

echo "🧪 Testing Semgrep API..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

API_URL="http://localhost:8000"

# Test 1: Health check
echo -e "${YELLOW}1. Health Check:${NC}"
if curl -s "$API_URL/health" | python3 -m json.tool; then
    echo -e "${GREEN}✅ Health check passed${NC}"
else
    echo -e "${RED}❌ Health check failed${NC}"
fi

echo ""

# Test 2: Basic scan
echo -e "${YELLOW}2. Basic Scan Test:${NC}"
curl -s -X POST "$API_URL/scan" \
    -H "Content-Type: application/json" \
    -d '{
        "code": "import os\nos.system(\"rm -rf /\")",
        "language": "python"
    }' | python3 -m json.tool

echo ""

# Test 3: Safe code scan
echo -e "${YELLOW}3. Safe Code Scan:${NC}"
curl -s -X POST "$API_URL/scan" \
    -H "Content-Type: application/json" \
    -d '{
        "code": "print(\"Hello, World!\")",
        "language": "python"
    }' | python3 -m json.tool

echo ""

# Test 4: Bulk scan
echo -e "${YELLOW}4. Bulk Scan Test:${NC}"
curl -s -X POST "$API_URL/scan/bulk" \
    -H "Content-Type: application/json" \
    -d '{
        "files": [
            {
                "filename": "test1.py",
                "content": "import subprocess\nsubprocess.call([\"ls\"])"
            },
            {
                "filename": "test2.js",
                "content": "eval(\"dangerous code\")"
            }
        ]
    }' | python3 -m json.tool

echo ""

# Test 5: Rules endpoint
echo -e "${YELLOW}5. Available Rules:${NC}"
curl -s "$API_URL/rules" | python3 -m json.tool | head -20

echo ""
echo -e "${GREEN}✅ All tests completed!${NC}"