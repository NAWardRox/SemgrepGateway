#!/bin/bash

# Semgrep Rules Manager - Complete Tool
# Usage: ./manage-rules.sh [command]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
RULES_DIR="rules"
CUSTOM_DIR="$RULES_DIR/custom"
DOWNLOADED_DIR="$RULES_DIR/downloaded"
API_URL="http://localhost:8000"

# Create directories
mkdir -p "$CUSTOM_DIR" "$DOWNLOADED_DIR"

# Helper functions
print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}   Semgrep Rules Manager v2.0${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

print_menu() {
    echo -e "${YELLOW}Available Commands:${NC}"
    echo "  1. download    - Download popular rulesets"
    echo "  2. list        - List available rules"
    echo "  3. custom      - Create custom rules"
    echo "  4. test        - Test rules with sample code"
    echo "  5. update      - Update existing rules"
    echo "  6. search      - Search for specific rules"
    echo "  7. install     - Install rule packs"
    echo "  8. backup      - Backup current rules"
    echo "  9. restore     - Restore rules from backup"
    echo "  10. clean      - Clean unused rules"
    echo "  11. status     - Show rules status"
    echo "  12. help       - Show detailed help"
    echo
    echo -e "${BLUE}Quick start: ./manage-rules.sh download${NC}"
}

check_semgrep() {
    if ! command -v semgrep &> /dev/null; then
        echo -e "${RED}❌ Semgrep not found. Installing...${NC}"
        pip install semgrep
    fi
    echo -e "${GREEN}✅ Semgrep available: $(semgrep --version | head -1)${NC}"
}

check_api() {
    if curl -s "$API_URL/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ API running at $API_URL${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ API not running at $API_URL${NC}"
        return 1
    fi
}

download_rules() {
    echo -e "${BLUE}📦 Downloading Semgrep Rules...${NC}"

    # Popular rulesets to download
    local rulesets=(
        "auto"
        "p/security-audit"
        "p/owasp-top-ten"
        "p/cwe-top-25"
        "p/python"
        "p/javascript"
        "p/typescript"
        "p/java"
        "p/go"
        "p/php"
        "p/ruby"
        "p/c"
        "p/cpp"
        "p/csharp"
        "r/python.django.security"
        "r/python.flask.security"
        "r/javascript.express.security"
        "r/javascript.node-js.security"
        "r/java.spring.security"
    )

    echo -e "${YELLOW}Downloading ${#rulesets[@]} popular rulesets...${NC}"

    for ruleset in "${rulesets[@]}"; do
        echo -n "  • $ruleset ... "
        if semgrep --config="$ruleset" --dry-run . >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done

    echo
    echo -e "${GREEN}✅ Rules download completed!${NC}"
    echo -e "${BLUE}Rules are cached in: ~/.semgrep${NC}"
}

list_rules() {
    echo -e "${BLUE}📋 Available Rules:${NC}"
    echo

    # List registry rules
    echo -e "${YELLOW}🌐 Registry Rules:${NC}"
    if command -v semgrep >/dev/null 2>&1; then
        semgrep --list-configs 2>/dev/null | head -20 | while read rule; do
            echo "  • $rule"
        done
        echo "  ... (and many more)"
    else
        echo "  Semgrep not installed"
    fi

    echo

    # List custom rules
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

    # Show popular configs
    echo -e "${YELLOW}⭐ Popular Configs:${NC}"
    local popular=(
        "auto - Auto-detect appropriate rules"
        "p/security-audit - Comprehensive security audit"
        "p/owasp-top-ten - OWASP Top 10 vulnerabilities"
        "p/python - Python-specific rules"
        "p/javascript - JavaScript/Node.js rules"
        "p/java - Java application rules"
        "p/go - Golang rules"
    )

    for config in "${popular[@]}"; do
        echo "  • $config"
    done
}

create_custom_rules() {
    echo -e "${BLUE}🛠️ Creating Custom Rules...${NC}"
    echo

    # Security Rules
    cat > "$CUSTOM_DIR/security-basics.yml" << 'EOF'
rules:
  - id: dangerous-os-system
    pattern: os.system($CMD)
    message: "Dangerous use of os.system() - use subprocess instead"
    languages: [python]
    severity: ERROR
    metadata:
      category: security
      cwe: "CWE-78: OS Command Injection"

  - id: dangerous-eval
    pattern: eval($CODE)
    message: "Dangerous use of eval() - code injection risk"
    languages: [python, javascript]
    severity: ERROR
    metadata:
      category: security
      cwe: "CWE-95: Code Injection"

  - id: sql-injection-format
    pattern: |
      cursor.execute("..." % $VAR)
    message: "SQL injection risk - use parameterized queries"
    languages: [python]
    severity: ERROR
    metadata:
      category: security
      cwe: "CWE-89: SQL Injection"

  - id: hardcoded-password
    pattern: |
      password = "$PASSWORD"
    message: "Hardcoded password detected"
    languages: [python, javascript, java]
    severity: WARNING
    metadata:
      category: security
      cwe: "CWE-798: Hardcoded Credentials"

  - id: unsafe-pickle
    pattern: pickle.loads($DATA)
    message: "Unsafe deserialization with pickle.loads()"
    languages: [python]
    severity: ERROR
    metadata:
      category: security
      cwe: "CWE-502: Unsafe Deserialization"
EOF

    # Web Security Rules
    cat > "$CUSTOM_DIR/web-security.yml" << 'EOF'
rules:
  - id: xss-risk
    pattern: |
      $RESPONSE.write($USER_INPUT)
    message: "Potential XSS vulnerability - sanitize user input"
    languages: [javascript]
    severity: ERROR
    metadata:
      category: security
      cwe: "CWE-79: Cross-site Scripting"

  - id: insecure-http
    pattern: |
      "http://$URL"
    message: "Insecure HTTP protocol - use HTTPS in production"
    languages: [python, javascript, java]
    severity: INFO
    metadata:
      category: security

  - id: weak-crypto-md5
    pattern: |
      md5($DATA)
    message: "Weak cryptographic hash MD5 - use SHA-256 or better"
    languages: [python, javascript, php]
    severity: WARNING
    metadata:
      category: security
      cwe: "CWE-328: Weak Hash"

  - id: missing-csrf-protection
    pattern: |
      app.post($PATH, function($REQ, $RES) { ... })
    message: "POST endpoint may need CSRF protection"
    languages: [javascript]
    severity: INFO
    metadata:
      category: security
      cwe: "CWE-352: CSRF"
EOF

    # API Security Rules
    cat > "$CUSTOM_DIR/api-security.yml" << 'EOF'
rules:
  - id: jwt-hardcoded-secret
    pattern: |
      jwt.encode($PAYLOAD, "$SECRET", ...)
    message: "JWT secret should not be hardcoded"
    languages: [python]
    severity: ERROR
    metadata:
      category: security

  - id: api-key-in-url
    pattern: |
      "$URL?api_key=$KEY"
    message: "API key in URL - use headers instead"
    languages: [python, javascript]
    severity: WARNING
    metadata:
      category: security

  - id: debug-mode-production
    pattern: |
      DEBUG = True
    message: "Debug mode should be disabled in production"
    languages: [python]
    severity: WARNING
    metadata:
      category: security
EOF

    # Code Quality Rules
    cat > "$CUSTOM_DIR/code-quality.yml" << 'EOF'
rules:
  - id: broad-exception-catch
    pattern: |
      try:
        ...
      except:
        ...
    message: "Catching all exceptions - be more specific"
    languages: [python]
    severity: INFO
    metadata:
      category: maintainability

  - id: print-statement-debug
    pattern: print($DEBUG_MSG)
    message: "Debug print statement - consider using logging"
    languages: [python]
    severity: INFO
    metadata:
      category: maintainability

  - id: todo-comment
    pattern: |
      # TODO: $MSG
    message: "TODO comment found - track in issue tracker"
    languages: [python, javascript, java]
    severity: INFO
    metadata:
      category: maintainability
EOF

    echo -e "${GREEN}✅ Custom rules created:${NC}"
    echo "  • $CUSTOM_DIR/security-basics.yml"
    echo "  • $CUSTOM_DIR/web-security.yml"
    echo "  • $CUSTOM_DIR/api-security.yml"
    echo "  • $CUSTOM_DIR/code-quality.yml"

    echo
    echo -e "${BLUE}📖 Usage examples:${NC}"
    echo "  semgrep --config=$CUSTOM_DIR/security-basics.yml ."
    echo "  curl -X POST \"$API_URL/scan\" -d '{\"code\":\"os.system(\\\"ls\\\")\",\"language\":\"python\",\"config\":\"$CUSTOM_DIR/security-basics.yml\"}'"
}

test_rules() {
    echo -e "${BLUE}🧪 Testing Rules with Sample Code...${NC}"
    echo

    # Create test directory
    local test_dir="test-samples"
    mkdir -p "$test_dir"

    # Python test file
    cat > "$test_dir/test.py" << 'EOF'
import os
import pickle
import subprocess
import jwt

# Security issues
os.system("rm -rf /")                    # Command injection
eval("print('hello')")                   # Code injection
password = "admin123"                    # Hardcoded password
data = pickle.loads(user_data)           # Unsafe deserialization
token = jwt.encode(payload, "secret")    # Hardcoded JWT secret

# SQL injection
query = "SELECT * FROM users WHERE id = '%s'" % user_id
cursor.execute(query)

# Quality issues
try:
    risky_operation()
except:
    pass

print("Debug: user logged in")           # Debug print

# TODO: implement proper error handling

# Good practices
subprocess.run(["ls", "-la"], check=True)
password = os.getenv("PASSWORD")
EOF

    # JavaScript test file
    cat > "$test_dir/test.js" << 'EOF'
// Security issues
eval(user_input);                        // Code injection
response.write(req.body.message);        // XSS risk
const api_url = "http://example.com/api?key=12345";  // Insecure HTTP + API key in URL

// Web security
app.post('/submit', function(req, res) { // Missing CSRF protection
    res.send('OK');
});

const hash = md5(password);              // Weak crypto

// TODO: add input validation
EOF

    echo -e "${YELLOW}Testing with different rule configs:${NC}"
    echo

    # Test with auto config
    echo -e "${BLUE}1. Auto config:${NC}"
    if check_api; then
        local python_code=$(cat "$test_dir/test.py" | sed 's/"/\\"/g' | tr '\n' ' ')
        curl -s -X POST "$API_URL/scan" \
            -H "Content-Type: application/json" \
            -d "{\"code\":\"$python_code\",\"language\":\"python\",\"config\":\"auto\"}" \
            | jq -r '.findings | length as $count | "Found \($count) issues"' 2>/dev/null || echo "API not responding"
    else
        semgrep --config=auto "$test_dir/test.py" --json | jq -r '.results | length as $count | "Found \($count) issues"' 2>/dev/null || echo "Direct scan: found issues"
    fi

    echo

    # Test with security audit
    echo -e "${BLUE}2. Security audit:${NC}"
    if command -v semgrep >/dev/null 2>&1; then
        semgrep --config=p/security-audit "$test_dir/" --json 2>/dev/null | jq -r '.results | length as $count | "Found \($count) security issues"' 2>/dev/null || echo "Found security issues"
    fi

    echo

    # Test with custom rules
    echo -e "${BLUE}3. Custom security rules:${NC}"
    if [ -f "$CUSTOM_DIR/security-basics.yml" ]; then
        semgrep --config="$CUSTOM_DIR/security-basics.yml" "$test_dir/" --json 2>/dev/null | jq -r '.results | length as $count | "Found \($count) custom rule matches"' 2>/dev/null || echo "Found custom rule matches"
    else
        echo "Custom rules not created yet - run './manage-rules.sh custom' first"
    fi

    echo

    # Show sample findings
    echo -e "${YELLOW}Sample scan output:${NC}"
    if command -v semgrep >/dev/null 2>&1; then
        semgrep --config=p/security-audit "$test_dir/test.py" 2>/dev/null | head -10 || echo "Run semgrep scan to see detailed output"
    fi

    # Cleanup
    rm -rf "$test_dir"

    echo
    echo -e "${GREEN}✅ Rule testing completed!${NC}"
}

update_rules() {
    echo -e "${BLUE}🔄 Updating Semgrep Rules...${NC}"

    # Update semgrep itself
    echo "Updating Semgrep..."
    pip install --upgrade semgrep

    # Clear cache and re-download
    echo "Clearing rules cache..."
    rm -rf ~/.semgrep/cache 2>/dev/null || true

    # Re-download popular rules
    download_rules

    echo -e "${GREEN}✅ Rules updated!${NC}"
}

search_rules() {
    echo -e "${BLUE}🔍 Search Rules:${NC}"
    echo

    read -p "Enter search term (e.g., 'sql', 'xss', 'python'): " search_term

    if [ -z "$search_term" ]; then
        echo "No search term provided"
        return 1
    fi

    echo -e "${YELLOW}Searching for rules containing '$search_term':${NC}"

    # Search in registry
    echo
    echo -e "${BLUE}Registry rules:${NC}"
    semgrep --list-configs 2>/dev/null | grep -i "$search_term" | head -10 || echo "No matches found"

    # Search in custom rules
    echo
    echo -e "${BLUE}Custom rules:${NC}"
    if [ -d "$CUSTOM_DIR" ]; then
        grep -r -i "$search_term" "$CUSTOM_DIR/" 2>/dev/null | head -5 || echo "No matches in custom rules"
    fi
}

install_rule_packs() {
    echo -e "${BLUE}📦 Install Rule Packs:${NC}"
    echo

    echo -e "${YELLOW}Available rule packs:${NC}"
    echo "1. Security Essentials (OWASP + CWE)"
    echo "2. Web Application Security"
    echo "3. API Security"
    echo "4. Cloud Security"
    echo "5. Mobile Security"
    echo "6. All Packs"
    echo

    read -p "Select pack (1-6): " choice

    case $choice in
        1)
            echo "Installing Security Essentials..."
            semgrep --config=p/security-audit --dry-run . >/dev/null 2>&1
            semgrep --config=p/owasp-top-ten --dry-run . >/dev/null 2>&1
            semgrep --config=p/cwe-top-25 --dry-run . >/dev/null 2>&1
            ;;
        2)
            echo "Installing Web Security..."
            semgrep --config=r/javascript.express.security --dry-run . >/dev/null 2>&1
            semgrep --config=r/python.django.security --dry-run . >/dev/null 2>&1
            semgrep --config=r/python.flask.security --dry-run . >/dev/null 2>&1
            ;;
        3)
            echo "Installing API Security..."
            create_custom_rules
            ;;
        6)
            echo "Installing all packs..."
            download_rules
            create_custom_rules
            ;;
        *)
            echo "Invalid selection"
            return 1
            ;;
    esac

    echo -e "${GREEN}✅ Rule pack installed!${NC}"
}

backup_rules() {
    echo -e "${BLUE}💾 Backing up Rules...${NC}"

    local backup_file="rules-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    if [ -d "$RULES_DIR" ]; then
        tar -czf "$backup_file" "$RULES_DIR"
        echo -e "${GREEN}✅ Backup created: $backup_file${NC}"
    else
        echo -e "${YELLOW}No rules directory to backup${NC}"
    fi
}

restore_rules() {
    echo -e "${BLUE}📂 Restore Rules:${NC}"
    echo

    echo "Available backups:"
    ls -la rules-backup-*.tar.gz 2>/dev/null || echo "No backups found"
    echo

    read -p "Enter backup filename: " backup_file

    if [ -f "$backup_file" ]; then
        echo "Restoring from $backup_file..."
        tar -xzf "$backup_file"
        echo -e "${GREEN}✅ Rules restored!${NC}"
    else
        echo -e "${RED}Backup file not found${NC}"
    fi
}

clean_rules() {
    echo -e "${BLUE}🧹 Cleaning Rules...${NC}"

    # Clear semgrep cache
    echo "Clearing Semgrep cache..."
    rm -rf ~/.semgrep/cache 2>/dev/null || true

    # Clean downloaded rules
    if [ -d "$DOWNLOADED_DIR" ]; then
        echo "Cleaning downloaded rules..."
        rm -rf "$DOWNLOADED_DIR"/*
    fi

    echo -e "${GREEN}✅ Rules cleaned!${NC}"
}

show_status() {
    echo -e "${BLUE}📊 Rules Status:${NC}"
    echo

    # Semgrep version
    if command -v semgrep >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Semgrep: $(semgrep --version | head -1)${NC}"
    else
        echo -e "${RED}❌ Semgrep: Not installed${NC}"
    fi

    # API status
    if check_api >/dev/null 2>&1; then
        echo -e "${GREEN}✅ API: Running at $API_URL${NC}"
    else
        echo -e "${YELLOW}⚠️ API: Not running${NC}"
    fi

    # Cache status
    if [ -d ~/.semgrep ]; then
        local cache_size=$(du -sh ~/.semgrep 2>/dev/null | cut -f1)
        echo -e "${BLUE}📦 Cache: $cache_size${NC}"
    else
        echo -e "${YELLOW}📦 Cache: Empty${NC}"
    fi

    # Custom rules count
    if [ -d "$CUSTOM_DIR" ]; then
        local custom_count=$(find "$CUSTOM_DIR" -name "*.yml" -o -name "*.yaml" | wc -l)
        echo -e "${BLUE}🛠️ Custom rules: $custom_count files${NC}"
    else
        echo -e "${YELLOW}🛠️ Custom rules: None${NC}"
    fi

    # Recent activity
    echo
    echo -e "${YELLOW}📋 Recent files:${NC}"
    if [ -d "$RULES_DIR" ]; then
        find "$RULES_DIR" -type f -mtime -7 2>/dev/null | head -5 || echo "No recent activity"
    fi
}

show_help() {
    echo -e "${BLUE}📖 Detailed Help:${NC}"
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo
    echo -e "${GREEN}download${NC}     - Download popular Semgrep rulesets"
    echo "               Includes security, language-specific, and framework rules"
    echo
    echo -e "${GREEN}list${NC}         - Show all available rules"
    echo "               Lists registry rules, custom rules, and popular configs"
    echo
    echo -e "${GREEN}custom${NC}       - Create comprehensive custom rule files"
    echo "               Generates security, web, API, and quality rules"
    echo
    echo -e "${GREEN}test${NC}         - Test rules with vulnerable sample code"
    echo "               Creates test files and runs scans to verify rules work"
    echo
    echo -e "${GREEN}update${NC}       - Update Semgrep and refresh rule cache"
    echo "               Upgrades semgrep and re-downloads rules"
    echo
    echo -e "${GREEN}search${NC}       - Search for specific rules by keyword"
    echo "               Interactive search through available rules"
    echo
    echo -e "${GREEN}install${NC}      - Install curated rule packs"
    echo "               Choose from security, web, API, or cloud rule collections"
    echo
    echo -e "${GREEN}backup${NC}       - Create timestamped backup of all rules"
    echo "               Saves custom rules and configurations"
    echo
    echo -e "${GREEN}restore${NC}      - Restore rules from backup file"
    echo "               Interactive restore from backup archives"
    echo
    echo -e "${GREEN}clean${NC}        - Clean cache and temporary files"
    echo "               Removes cached rules and temporary downloads"
    echo
    echo -e "${GREEN}status${NC}       - Show comprehensive system status"
    echo "               Displays semgrep version, API status, cache info"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ./manage-rules.sh download"
    echo "  ./manage-rules.sh test"
    echo "  ./manage-rules.sh search sql"
    echo "  ./manage-rules.sh custom && ./manage-rules.sh test"
}

# Main script logic
main() {
    print_header

    if [ $# -eq 0 ]; then
        print_menu
        echo
        read -p "Enter command (or 'help' for details): " cmd
    else
        cmd=$1
    fi

    case $cmd in
        "download"|"d"|"1")
            check_semgrep
            download_rules
            ;;
        "list"|"l"|"2")
            list_rules
            ;;
        "custom"|"c"|"3")
            create_custom_rules
            ;;
        "test"|"t"|"4")
            check_semgrep
            test_rules
            ;;
        "update"|"u"|"5")
            update_rules
            ;;
        "search"|"s"|"6")
            search_rules
            ;;
        "install"|"i"|"7")
            install_rule_packs
            ;;
        "backup"|"b"|"8")
            backup_rules
            ;;
        "restore"|"r"|"9")
            restore_rules
            ;;
        "clean"|"10")
            clean_rules
            ;;
        "status"|"11")
            show_status
            ;;
        "help"|"h"|"12")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            echo
            print_menu
            ;;
    esac
}

# Run main function
main "$@"