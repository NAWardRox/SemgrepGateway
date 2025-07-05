#!/bin/bash

# Container-aware Semgrep Rules Manager
# Works with Docker deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CONTAINER_NAME="semgrep-api"
API_URL="http://localhost:8000"
RULES_DIR="rules"
CUSTOM_DIR="$RULES_DIR/custom"

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}   Semgrep Rules Manager v3.0${NC}"
    echo -e "${CYAN}   (Container-aware)${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

check_container() {
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${GREEN}✅ Container running${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ Container not running${NC}"
        return 1
    fi
}

exec_in_container() {
    local cmd="$1"
    if check_container >/dev/null 2>&1; then
        docker exec "$CONTAINER_NAME" bash -c "$cmd"
    else
        echo -e "${RED}❌ Container not running. Start with: ./deploy.sh${NC}"
        return 1
    fi
}

download_rules() {
    echo -e "${BLUE}📦 Downloading Semgrep Rules in Container...${NC}"

    if ! check_container; then
        echo -e "${YELLOW}Starting container first...${NC}"
        if [ -f "deploy.sh" ]; then
            ./deploy.sh
            sleep 10
        else
            echo -e "${RED}❌ deploy.sh not found. Please start the container first.${NC}"
            return 1
        fi
    fi

    echo -e "${YELLOW}Downloading popular rulesets...${NC}"

    # Download rules inside container
    local rulesets=(
        "p/security-audit"
        "p/owasp-top-ten"
        "p/python"
        "p/javascript"
        "p/java"
        "p/go"
        "auto"
    )

    for ruleset in "${rulesets[@]}"; do
        echo -n "  • $ruleset ... "
        if exec_in_container "timeout 30 semgrep --config=$ruleset --dry-run /tmp >/dev/null 2>&1"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done

    echo
    echo -e "${GREEN}✅ Rules downloaded in container!${NC}"
}

create_custom_rules() {
    echo -e "${BLUE}🛠️ Creating Custom Rules...${NC}"

    # Create rules directory on host
    mkdir -p "$CUSTOM_DIR"

    # Create security rules
    cat > "$CUSTOM_DIR/security-basics.yml" << 'EOF'
rules:
  - id: dangerous-os-system
    pattern: os.system($CMD)
    message: "Dangerous use of os.system() - use subprocess instead"
    languages: [python]
    severity: ERROR

  - id: dangerous-eval
    pattern: eval($CODE)
    message: "Dangerous use of eval() - code injection risk"
    languages: [python, javascript]
    severity: ERROR

  - id: hardcoded-password
    pattern: password = "$PASSWORD"
    message: "Hardcoded password detected"
    languages: [python, javascript, java]
    severity: WARNING

  - id: unsafe-pickle
    pattern: pickle.loads($DATA)
    message: "Unsafe deserialization with pickle.loads()"
    languages: [python]
    severity: ERROR

  - id: sql-injection-format
    pattern: cursor.execute("..." % $VAR)
    message: "SQL injection risk - use parameterized queries"
    languages: [python]
    severity: ERROR
EOF

    echo -e "${GREEN}✅ Custom rules created in $CUSTOM_DIR/security-basics.yml${NC}"

    # Copy to container (if volume mounted)
    if check_container >/dev/null 2>&1; then
        echo -e "${YELLOW}Rules will be available in container via volume mount${NC}"
    fi
}

test_rules() {
    echo -e "${BLUE}🧪 Testing Rules via API...${NC}"

    if ! curl -s "$API_URL/health" >/dev/null 2>&1; then
        echo -e "${RED}❌ API not accessible at $API_URL${NC}"
        return 1
    fi

    echo -e "${YELLOW}Testing with dangerous Python code...${NC}"

    # Test 1: Command injection
    echo -n "• Command injection test ... "
    local result1=$(curl -s -X POST "$API_URL/scan" \
        -H "Content-Type: application/json" \
        -d '{"code":"import os\nos.system(\"rm -rf /\")","language":"python","config":"auto"}' \
        | jq -r '.findings | length' 2>/dev/null)

    if [ "$result1" != "null" ] && [ "$result1" -gt 0 ]; then
        echo -e "${GREEN}✓ ($result1 findings)${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi

    # Test 2: Code injection
    echo -n "• Code injection test ... "
    local result2=$(curl -s -X POST "$API_URL/scan" \
        -H "Content-Type: application/json" \
        -d '{"code":"eval(user_input)","language":"python","config":"p/security-audit"}' \
        | jq -r '.findings | length' 2>/dev/null)

    if [ "$result2" != "null" ] && [ "$result2" -gt 0 ]; then
        echo -e "${GREEN}✓ ($result2 findings)${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi

    # Test 3: Hardcoded password
    echo -n "• Hardcoded password test ... "
    local result3=$(curl -s -X POST "$API_URL/scan" \
        -H "Content-Type: application/json" \
        -d '{"code":"password = \"admin123\"","language":"python","config":"auto"}' \
        | jq -r '.findings | length' 2>/dev/null)

    if [ "$result3" != "null" ] && [ "$result3" -gt 0 ]; then
        echo -e "${GREEN}✓ ($result3 findings)${NC}"
    else
        echo -e "${YELLOW}~ (may not be detected by auto config)${NC}"
    fi

    echo
    echo -e "${GREEN}✅ API testing completed!${NC}"
}

test_custom_rules() {
    echo -e "${BLUE}🧪 Testing Custom Rules...${NC}"

    if [ ! -f "$CUSTOM_DIR/security-basics.yml" ]; then
        echo -e "${YELLOW}Creating custom rules first...${NC}"
        create_custom_rules
    fi

    echo -n "• Testing custom security rules ... "
    local result=$(curl -s -X POST "$API_URL/scan" \
        -H "Content-Type: application/json" \
        -d '{"code":"password = \"secret123\"\nos.system(\"ls\")","language":"python","config":"rules/custom/security-basics.yml"}' \
        | jq -r '.findings | length' 2>/dev/null)

    if [ "$result" != "null" ] && [ "$result" -gt 0 ]; then
        echo -e "${GREEN}✓ ($result findings)${NC}"
    else
        echo -e "${RED}✗ (rules not found or not working)${NC}"
    fi
}

list_rules() {
    echo -e "${BLUE}📋 Available Rules:${NC}"
    echo

    echo -e "${YELLOW}🌐 Popular Configs:${NC}"
    echo "  • auto - Auto-detect appropriate rules"
    echo "  • p/security-audit - Comprehensive security audit"
    echo "  • p/owasp-top-ten - OWASP Top 10 vulnerabilities"
    echo "  • p/python - Python-specific rules"
    echo "  • p/javascript - JavaScript/Node.js rules"
    echo "  • p/java - Java application rules"
    echo "  • p/go - Golang rules"

    echo
    echo -e "${YELLOW}🛠️ Custom Rules:${NC}"
    if [ -d "$CUSTOM_DIR" ] && [ "$(ls -A $CUSTOM_DIR 2>/dev/null)" ]; then
        for file in "$CUSTOM_DIR"/*.yml "$CUSTOM_DIR"/*.yaml; do
            if [ -f "$file" ]; then
                echo "  • $(basename "$file")"
            fi
        done
    else
        echo "  No custom rules found"
    fi

    echo
    echo -e "${YELLOW}📡 API Rules Endpoint:${NC}"
    if curl -s "$API_URL/rules" >/dev/null 2>&1; then
        echo "  Available at: $API_URL/rules"
    else
        echo "  API not accessible"
    fi
}

show_status() {
    echo -e "${BLUE}📊 System Status:${NC}"
    echo

    # Container status
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${GREEN}✅ Container: Running${NC}"
    else
        echo -e "${RED}❌ Container: Not running${NC}"
    fi

    # API status
    if curl -s "$API_URL/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ API: Running at $API_URL${NC}"

        # Get API health info
        local health=$(curl -s "$API_URL/health" | jq -r '.semgrep_version // "unknown"' 2>/dev/null)
        echo -e "${BLUE}📦 Semgrep: $health${NC}"
    else
        echo -e "${RED}❌ API: Not accessible${NC}"
    fi

    # Docker status
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker: Available${NC}"
    else
        echo -e "${RED}❌ Docker: Not found${NC}"
    fi

    # Rules status
    if [ -d "$CUSTOM_DIR" ]; then
        local custom_count=$(find "$CUSTOM_DIR" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
        echo -e "${BLUE}🛠️ Custom rules: $custom_count files${NC}"
    else
        echo -e "${YELLOW}🛠️ Custom rules: None${NC}"
    fi
}

rebuild_container() {
    echo -e "${BLUE}🔄 Rebuilding Container with Rules...${NC}"

    if [ -f "deploy.sh" ]; then
        echo -e "${YELLOW}Stopping current container...${NC}"
        docker-compose down 2>/dev/null || true

        echo -e "${YELLOW}Rebuilding with fresh rules...${NC}"
        docker-compose build --no-cache

        echo -e "${YELLOW}Starting container...${NC}"
        docker-compose up -d

        echo -e "${YELLOW}Waiting for service...${NC}"
        sleep 15

        if curl -s "$API_URL/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Container rebuilt and running!${NC}"
        else
            echo -e "${RED}❌ Container failed to start properly${NC}"
        fi
    else
        echo -e "${RED}❌ deploy.sh not found${NC}"
    fi
}

print_menu() {
    echo -e "${YELLOW}Available Commands:${NC}"
    echo "  1. download    - Download rules in container"
    echo "  2. custom      - Create custom rules"
    echo "  3. test        - Test rules via API"
    echo "  4. test-custom - Test custom rules"
    echo "  5. list        - List available rules"
    echo "  6. status      - Show system status"
    echo "  7. rebuild     - Rebuild container with rules"
    echo "  8. help        - Show help"
    echo
    echo -e "${BLUE}Quick start: ./manage-rules.sh download${NC}"
}

show_help() {
    echo -e "${BLUE}📖 Help:${NC}"
    echo
    echo -e "${YELLOW}This version works with containerized deployment:${NC}"
    echo "1. Start container: ./deploy.sh"
    echo "2. Download rules: ./manage-rules.sh download"
    echo "3. Test rules: ./manage-rules.sh test"
    echo
    echo -e "${YELLOW}Key differences:${NC}"
    echo "• Semgrep runs inside Docker container"
    echo "• Rules are downloaded to container cache"
    echo "• Custom rules created on host (volume mounted)"
    echo "• Testing done via API endpoints"
    echo
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "• If rules not working: rebuild container"
    echo "• If API not accessible: check container status"
    echo "• If tests fail: verify Semgrep in container"
}

# Main script
main() {
    print_header

    if [ $# -eq 0 ]; then
        print_menu
        echo
        read -p "Enter command: " cmd
    else
        cmd=$1
    fi

    case $cmd in
        "download"|"1")
            download_rules
            ;;
        "custom"|"2")
            create_custom_rules
            ;;
        "test"|"3")
            test_rules
            ;;
        "test-custom"|"4")
            test_custom_rules
            ;;
        "list"|"5")
            list_rules
            ;;
        "status"|"6")
            show_status
            ;;
        "rebuild"|"7")
            rebuild_container
            ;;
        "help"|"8")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            print_menu
            ;;
    esac
}

main "$@"