#!/bin/bash

# Update Semgrep to Latest Version Script
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔄 Updating Semgrep to Latest Version${NC}"

# Function to check current version
check_current_version() {
    if docker ps | grep -q semgrep-api; then
        local current_version=$(docker exec $(docker ps --filter "name=semgrep-api" --format "{{.Names}}" | head -1) semgrep --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "${YELLOW}Current Semgrep version in container: $current_version${NC}"
    else
        echo -e "${YELLOW}Container not running${NC}"
    fi
}

# Function to get latest version from PyPI
get_latest_version() {
    echo -e "${YELLOW}📡 Checking latest Semgrep version from PyPI...${NC}"
    local latest_version=$(curl -s https://pypi.org/pypi/semgrep/json | jq -r '.info.version' 2>/dev/null || echo "unknown")
    echo -e "${BLUE}Latest Semgrep version available: $latest_version${NC}"
}

# Method 1: Update in running container (quick)
update_in_container() {
    echo -e "${YELLOW}🔄 Method 1: Quick update in running container${NC}"

    if ! docker ps | grep -q semgrep-api; then
        echo -e "${RED}❌ Container not running${NC}"
        return 1
    fi

    local container_name=$(docker ps --filter "name=semgrep-api" --format "{{.Names}}" | head -1)

    echo "Updating Semgrep in container..."
    docker exec "$container_name" pip install --upgrade semgrep

    echo "New version:"
    docker exec "$container_name" semgrep --version

    echo "Clearing rules cache..."
    docker exec "$container_name" bash -c 'rm -rf ~/.semgrep/cache 2>/dev/null || true'

    echo "Re-downloading popular rules..."
    docker exec "$container_name" timeout 60 semgrep --config=p/security-audit /tmp --json >/dev/null 2>&1 || true
    docker exec "$container_name" timeout 60 semgrep --config=p/python /tmp --json >/dev/null 2>&1 || true

    echo -e "${GREEN}✅ Quick update completed${NC}"
}

# Method 2: Rebuild container with latest (thorough)
rebuild_with_latest() {
    echo -e "${YELLOW}🔨 Method 2: Rebuild container with latest Semgrep${NC}"

    # Update Dockerfile to use latest
    echo "Updating Dockerfile..."
    if grep -q "semgrep==" Dockerfile; then
        sed -i 's/semgrep==[0-9.]*/semgrep/' Dockerfile
        echo "Removed version pinning from Dockerfile"
    fi

    # Update requirements.txt
    echo "Updating requirements.txt..."
    if grep -q "semgrep==" requirements.txt; then
        sed -i '/semgrep==/d' requirements.txt
        echo "Removed semgrep from requirements.txt (will be installed via Dockerfile)"
    fi

    # Stop current container
    echo "Stopping current container..."
    docker-compose down

    # Build with no cache to ensure latest
    echo "Building with latest Semgrep (no cache)..."
    docker-compose build --no-cache --pull

    # Start new container
    echo "Starting updated container..."
    docker-compose up -d

    # Wait for container to be ready
    echo "Waiting for container to be ready..."
    sleep 30

    # Verify new version
    echo "Verifying new version..."
    if docker ps | grep -q semgrep-api; then
        local new_container=$(docker ps --filter "name=semgrep-api" --format "{{.Names}}" | head -1)
        docker exec "$new_container" semgrep --version

        # Test basic functionality
        echo "Testing basic functionality..."
        docker exec "$new_container" bash -c 'echo "eval(input())" > test.py && semgrep --config=p/python test.py --json'

        echo -e "${GREEN}✅ Rebuild completed${NC}"
    else
        echo -e "${RED}❌ Container failed to start${NC}"
        return 1
    fi
}

# Method 3: Use specific latest version
use_specific_version() {
    echo -e "${YELLOW}📌 Method 3: Pin to specific latest version${NC}"

    local latest_version=$1
    if [ -z "$latest_version" ]; then
        latest_version=$(curl -s https://pypi.org/pypi/semgrep/json | jq -r '.info.version' 2>/dev/null || echo "1.50.0")
    fi

    echo "Pinning to version: $latest_version"

    # Update requirements.txt with specific version
    if grep -q "semgrep" requirements.txt; then
        sed -i "s/semgrep.*/semgrep==$latest_version/" requirements.txt
    else
        echo "semgrep==$latest_version" >> requirements.txt
    fi

    echo "Updated requirements.txt with semgrep==$latest_version"

    # Rebuild
    rebuild_with_latest
}

# Method 4: Enable automatic updates
enable_auto_updates() {
    echo -e "${YELLOW}🔄 Method 4: Enable automatic updates${NC}"

    # Create update script in container
    cat > update-semgrep-internal.sh << 'EOF'
#!/bin/bash
echo "Checking for Semgrep updates..."
current=$(semgrep --version | head -1)
pip install --upgrade semgrep
new=$(semgrep --version | head -1)
if [ "$current" != "$new" ]; then
    echo "Updated: $current -> $new"
    rm -rf ~/.semgrep/cache 2>/dev/null || true
    echo "Cache cleared"
else
    echo "Already latest: $current"
fi
EOF

    chmod +x update-semgrep-internal.sh

    echo "Created internal update script"
    echo "To run updates, use: docker exec <container> /app/update-semgrep-internal.sh"
}

# Interactive menu
show_menu() {
    echo -e "${BLUE}Choose update method:${NC}"
    echo "1. Quick update in running container"
    echo "2. Rebuild container with latest (recommended)"
    echo "3. Pin to specific version"
    echo "4. Enable auto-update script"
    echo "5. Check versions only"
    echo ""
    read -p "Select option (1-5): " choice

    case $choice in
        1)
            check_current_version
            update_in_container
            ;;
        2)
            check_current_version
            get_latest_version
            rebuild_with_latest
            ;;
        3)
            get_latest_version
            read -p "Enter version to pin (press enter for latest): " version
            use_specific_version "$version"
            ;;
        4)
            enable_auto_updates
            ;;
        5)
            check_current_version
            get_latest_version
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Main execution
if [ $# -eq 0 ]; then
    check_current_version
    get_latest_version
    show_menu
else
    case $1 in
        "quick")
            update_in_container
            ;;
        "rebuild")
            rebuild_with_latest
            ;;
        "version")
            check_current_version
            get_latest_version
            ;;
        *)
            echo "Usage: $0 [quick|rebuild|version]"
            ;;
    esac
fi