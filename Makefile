.PHONY: help install dev test clean build deploy stop logs

# Default target
help:
	@echo "Available commands:"
	@echo "  install    - Install dependencies"
	@echo "  dev        - Run development server"
	@echo "  test       - Run tests"
	@echo "  clean      - Clean temporary files"
	@echo "  build      - Build Docker image"
	@echo "  deploy     - Deploy with Docker"
	@echo "  deploy-prod- Deploy production"
	@echo "  stop       - Stop containers"
	@echo "  logs       - Show logs"

# Install dependencies
install:
	./setup.sh

# Run development server
dev:
	./run-dev.sh

# Run tests
test:
	./test.sh

# Clean temporary files
clean:
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	rm -rf build/ dist/ .pytest_cache/ logs/*.log

# Build Docker image
build:
	docker-compose build

# Deploy development
deploy:
	./deploy.sh

# Deploy production
deploy-prod:
	./deploy.sh prod

# Stop containers
stop:
	docker-compose down
	docker-compose -f docker-compose.prod.yml down

# Show logs
logs:
	docker-compose logs -f