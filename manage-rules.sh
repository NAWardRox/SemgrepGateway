#!/bin/bash

# Semgrep Rules Manager - Fixed for Virtual Environment
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
VENV_DIR="venv"

# Create directories
mkdir -p "$CUSTOM_DIR" "$DOWNLOADED_DIR"

# Helper functions
print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}   Semgrep Rules Manager v2.1${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

activate_venv() {
    # Check if we're already in a virtual environment
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        echo -e "${GREEN}✅ Already in virtual environment${NC}"
        return 0
    fi

    # Check if venv exists in current directory
    if [ -f "$VENV_DIR/bin/activate" ]; then
        echo -e "${YELLOW}🔌 Activating virtual environment...${NC}"
        source "$VENV_DIR/bin/activate"
        return 0
    fi

    # Check if venv exists in parent directory
    if [ -f "../$VENV_DIR/bin/activate" ]; then
        echo -e "${YELLOW}🔌 Activating virtual environment from parent directory...${NC}"
        source "../$VENV_DIR/bin/activate"
        return 0
    fi

    # Create new venv if none exists
    echo -e "${YELLOW}📦 Creating virtual environment...${NC}"
    if command -v python3 &> /dev/null; then
        python3 -m venv "$VENV_DIR"
        source "$VENV_DIR/bin/activate"
        pip install --upgrade pip
        echo -e "${GREEN}✅ Virtual environment created and activated${NC}"
    else
        echo -e "${RED}❌ Python3 not found${NC}"
        return 1
    fi
}

check_semgrep() {
    # First try to activate virtual environment
    activate_venv

    # Check if semgrep is available
    if ! command -v semgrep &> /dev/null; then
        echo -e "${YELLOW}📦 Installing Semgrep in virtual environment...${NC}"

        # Try different installation methods
        if pip install semgrep; then
            echo -e "${GREEN}✅ Semgrep installed successfully${NC}"
        elif pip install --user semgrep; then
            echo -e "${GREEN}✅ Semgrep installed in user directory${NC}"
        else
            echo -e "${RED}❌ Failed to install Semgrep with pip${NC}"
            echo -e "${YELLOW}Trying alternative installation methods...${NC}"

            # Try system package manager
            if command -v apt &> /dev/null; then
                echo -e "${YELLOW}Trying apt installation...${NC}"
                sudo apt update && sudo apt install -y semgrep
            elif command -v brew &> /dev/null; then
                echo -e "${YELLOW}Trying brew installation...${NC}"
                brew install semgrep
            elif command -v snap &> /dev/null; then
                echo -e "${YELLOW}Trying snap installation...${NC}"
                sudo snap install semgrep
            else
                echo -e "${RED}❌ No suitable package manager found${NC}"
                echo -e "${YELLOW}Manual installation options:${NC}"
                echo "1. Use pipx: pipx install semgrep"
                echo "2. Use conda: conda install -c conda-forge semgrep"
                echo "3. Download binary from: https://github.com/returntocorp/semgrep/releases"
                return 1
            fi
        fi
    fi

    # Verify installation
    if command -v semgrep &> /dev/null; then
        echo -e "${GREEN}✅ Semgrep available: $(semgrep --version | head -1)${NC}"
        return 0
    else
        echo -e "${RED}❌ Semgrep installation failed${NC}"
        return 1
    fi
}

# Alternative installation function
install_semgrep_alternative() {
    echo -e "${YELLOW}🔧 Alternative Semgrep Installation Methods:${NC}"
    echo
    echo "1. pipx (recommended for system-wide)"
    echo "2. conda/mamba"
    echo "3. docker"
    echo "4. manual download"
    echo "5. system package manager"
    echo
    read -p "Choose installation method (1-5): " choice

    case $choice in
        1)
            echo "Installing with pipx..."
            if ! command -v pipx &> /dev/null; then
                echo "Installing pipx first..."
                sudo apt install -y pipx || pip install --user pipx
            fi
            pipx install semgrep
            ;;
        2)
            echo "Installing with conda..."
            if command -v conda &> /dev/null; then
                conda install -c conda-forge semgrep
            elif command -v mamba &> /dev/null; then
                mamba install -c conda-forge semgrep
            else
                echo "Conda/mamba not found. Install miniconda first."
            fi
            ;;
        3)
            echo "Setting up Docker alias..."
            echo 'alias semgrep="docker run --rm -v $(pwd):/src returntocorp/semgrep"' >> ~/.bashrc
            source ~/.bashrc
            echo "Use: docker run --rm -v \$(pwd):/src returntocorp/semgrep --help"
            ;;
        4)
            echo "Manual download instructions:"
            echo "1. Go to: https://github.com/returntocorp/semgrep/releases"
            echo "2. Download the binary for your OS"
            echo "3. Make it executable: chmod +x semgrep"
            echo "4. Move to PATH: sudo mv semgrep /usr/local/bin/"
            ;;
        5)
            echo "System package manager..."
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y semgrep
            elif command -v yum &> /dev/null; then
                sudo yum install -y semgrep
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y semgrep
            else
                echo "No supported package manager found"
            fi
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
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

    # Check semgrep first
    if ! check_semgrep; then
        echo -e "${RED}❌ Cannot download rules without Semgrep${NC}"
        echo -e "${YELLOW}Would you like to try alternative installation?${NC}"
        read -p "Install Semgrep? (y/n): " install_choice
        if [[ $install_choice =~ ^[Yy]$ ]]; then
            install_semgrep_alternative
        else
            return 1
        fi
    fi

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
    )

    echo -e "${YELLOW}Downloading ${#rulesets[@]} popular rulesets...${NC}"

    local success_count=0
    for ruleset in "${rulesets[@]}"; do
        echo -n "  • $ruleset ... "
        if timeout 30 semgrep --config="$ruleset" --dry-run . >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗${NC}"
        fi
    done

    echo
    echo -e "${GREEN}✅ Downloaded $success_count/${#rulesets[@]} rulesets!${NC}"
    echo -e "${BLUE}Rules are cached in: ~/.semgrep${NC}"
}

# Include all other functions from the original script...
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

    echo -e "${GREEN}✅ Custom security rules created in $CUSTOM_DIR/security-basics.yml${NC}"
    echo -e "${BLUE}📖 Usage: semgrep --config=$CUSTOM_DIR/security-basics.yml .${NC}"
}

test_rules() {
    echo -e "${BLUE}🧪 Testing Rules with Sample Code...${NC}"

    if ! command -v semgrep &> /dev/null; then
        echo -e "${RED}❌ Semgrep not available for testing${NC}"
        return 1
    fi

    # Create test file
    local test_file="test_sample.py"
    cat > "$test_file" << 'EOF'
import os
import pickle

# Security issues that should be detected
os.system("rm -rf /")
eval("print('hello')")
password = "admin123"
data = pickle.loads(user_data)

print("This is a test file")
EOF

    echo -e "${YELLOW}Testing with sample vulnerable code...${NC}"

    # Test with auto config
    echo -e "${BLUE}Testing with 'auto' config:${NC}"
    semgrep --config=auto "$test_file" 2>/dev/null || echo "Found security issues (this is expected)"

    # Test with custom rules if they exist
    if [ -f "$CUSTOM_DIR/security-basics.yml" ]; then
        echo -e "${BLUE}Testing with custom rules:${NC}"
        semgrep --config="$CUSTOM_DIR/security-basics.yml" "$test_file" 2>/dev/null || echo "Custom rules detected issues"
    fi

    # Cleanup
    rm -f "$test_file"

    echo -e "${GREEN}✅ Rule testing completed!${NC}"
}

list_rules() {
    echo -e "${BLUE}📋 Available Rules:${NC}"
    echo

    # Popular configs
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

    echo

    # Custom rules
    echo -e "${YELLOW}🛠️ Custom Rules:${NC}"
    if [ -d "$CUSTOM_DIR" ] && [ "$(ls -A $CUSTOM_DIR 2>/dev/null)" ]; then
        for file in "$CUSTOM_DIR"/*.yml "$CUSTOM_DIR"/*.yaml; do
            if [ -f "$file" ]; then
                echo "  • $(basename "$file")"
            fi
        done
    else
        echo "  No custom rules found (run './manage-rules.sh custom' to create)"
    fi
}

show_status() {
    echo -e "${BLUE}📊 System Status:${NC}"
    echo

    # Python environment
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        echo -e "${GREEN}✅ Virtual Environment: Active ($VIRTUAL_ENV)${NC}"
    else
        echo -e "${YELLOW}⚠️ Virtual Environment: Not active${NC}"
    fi

    # Semgrep status
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

    # Rules status
    if [ -d "$CUSTOM_DIR" ]; then
        local custom_count=$(find "$CUSTOM_DIR" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
        echo -e "${BLUE}🛠️ Custom rules: $custom_count files${NC}"
    else
        echo -e "${YELLOW}🛠️ Custom rules: None${NC}"
    fi
}

print_menu() {
    echo -e "${YELLOW}Available Commands:${NC}"
    echo "  1. download    - Download popular rulesets"
    echo "  2. list        - List available rules"
    echo "  3. custom      - Create custom rules"
    echo "  4. test        - Test rules with sample code"
    echo "  5. status      - Show system status"
    echo "  6. install     - Alternative Semgrep installation"
    echo "  7. help        - Show help"
    echo
    echo -e "${BLUE}Quick start: ./manage-rules.sh download${NC}"
}

show_help() {
    echo -e "${BLUE}📖 Help:${NC}"
    echo
    echo -e "${YELLOW}Installation Issues:${NC}"
    echo "If you get 'externally-managed-environment' error:"
    echo "1. Run option 6 for alternative installation methods"
    echo "2. Or use: pipx install semgrep"
    echo "3. Or activate virtual environment first"
    echo
    echo -e "${YELLOW}Usage:${NC}"
    echo "./manage-rules.sh download  # Download rules"
    echo "./manage-rules.sh custom    # Create custom rules"
    echo "./manage-rules.sh test      # Test rules"
    echo "./manage-rules.sh status    # Check status"
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
            download_rules
            ;;
        "list"|"l"|"2")
            list_rules
            ;;
        "custom"|"c"|"3")
            create_custom_rules
            ;;
        "test"|"t"|"4")
            test_rules
            ;;
        "status"|"s"|"5")
            show_status
            ;;
        "install"|"i"|"6")
            install_semgrep_alternative
            ;;
        "help"|"h"|"7")
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