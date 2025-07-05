# 🚀 Semgrep API

<div align="center">

[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Semgrep](https://img.shields.io/badge/Semgrep-FF6B6B?style=for-the-badge&logo=semgrep&logoColor=white)](https://semgrep.dev/)

**Production-ready REST API for Semgrep code security scanning**

[Features](#-features) • [Quick Start](#-quick-start) • [API Documentation](#-api-usage) • [Deployment](#-docker-deployment) • [Contributing](#-contributing)

</div>

---

## 📋 Table of Contents

- [Features](#-features)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [API Usage](#-api-usage)
- [Configuration](#-configuration)
- [Docker Deployment](#-docker-deployment)
- [Development](#-development)
- [Testing](#-testing)
- [Monitoring](#-monitoring)
- [Security](#-security)
- [Production Deployment](#-production-deployment)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

<table>
<tr>
<td>

### 🔍 **Code Security Scanning**
- Powered by Semgrep engine
- 50+ programming languages
- Custom rules support
- Bulk file scanning

</td>
<td>

### ⚡ **High Performance**
- Async FastAPI framework
- Concurrent request handling
- Optimized Docker images
- Resource management

</td>
</tr>
<tr>
<td>

### 🐋 **Production Ready**
- Complete Docker setup
- Multi-stage builds
- Health checks
- Auto-scaling support

</td>
<td>

### 🔒 **Security Features**
- Input validation
- File size limits
- Rate limiting
- Non-root containers

</td>
</tr>
<tr>
<td>

### 📊 **Monitoring**
- Health endpoints
- Structured logging
- Performance metrics
- Error tracking

</td>
<td>

### 📚 **Developer Experience**
- Auto-generated docs
- Comprehensive tests
- Easy setup scripts
- Clear documentation

</td>
</tr>
</table>

## 🚀 Quick Start

### One-Command Setup

```bash
# Clone and setup
git clone https://github.com/yourusername/semgrep-api.git
cd semgrep-api
chmod +x *.sh && ./setup.sh

# Deploy
./deploy.sh
```

### Access Points
- **API**: http://localhost:8000
- **Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

## 📦 Installation

### Prerequisites

- **Python 3.8+**
- **Docker & Docker Compose**
- **4GB RAM minimum**

### Method 1: Docker (Recommended)

```bash
# Clone repository
git clone https://github.com/yourusername/semgrep-api.git
cd semgrep-api

# Deploy with Docker
./deploy.sh
```

### Method 2: Local Development

```bash
# Setup virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
cp .env.example .env

# Run development server
./run-dev.sh
```

### Method 3: Production

```bash
# Production deployment
./deploy.sh prod
```

## 📡 API Usage

### Scan Single Code Snippet

<details>
<summary>Click to expand</summary>

```bash
curl -X POST "http://localhost:8000/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "import os\nos.system(\"rm -rf /\")",
    "language": "python"
  }'
```

**Response:**
```json
{
  "findings": [
    {
      "rule_id": "python.lang.security.dangerous-subprocess-use",
      "message": "Found subprocess function 'os.system' used with user input",
      "severity": "ERROR",
      "line": 2
    }
  ],
  "errors": [],
  "stats": {},
  "execution_time": 0.45
}
```

</details>

### Bulk Scan Multiple Files

<details>
<summary>Click to expand</summary>

```bash
curl -X POST "http://localhost:8000/scan/bulk" \
  -H "Content-Type: application/json" \
  -d '{
    "files": [
      {
        "filename": "app.py",
        "content": "import subprocess\nsubprocess.call([\"ls\"])"
      },
      {
        "filename": "script.js",
        "content": "eval(user_input)"
      }
    ]
  }'
```

</details>

### Upload and Scan Files

<details>
<summary>Click to expand</summary>

```bash
curl -X POST "http://localhost:8000/scan/upload" \
  -F "files=@script.py" \
  -F "files=@app.js" \
  -F "config=auto"
```

</details>

### Health Check

```bash
curl http://localhost:8000/health
```

### Available Semgrep Rules

```bash
curl http://localhost:8000/rules
```

## 🔧 Configuration

### Environment Variables

Create `.env` file from `.env.example`:

```bash
# Environment
ENVIRONMENT=development          # development/production
DEBUG=true                      # Enable debug mode

# Server Configuration
HOST=0.0.0.0                   # Server host
PORT=8000                      # Server port

# Security
API_KEY=your-api-key           # Optional API authentication
SECRET_KEY=your-secret-key     # JWT secret key

# Semgrep Configuration
SEMGREP_TIMEOUT=300            # Scan timeout (seconds)
MAX_FILE_SIZE=10485760         # Max file size (10MB)
MAX_FILES_PER_REQUEST=50       # Max files per bulk request

# Logging
LOG_LEVEL=INFO                 # DEBUG/INFO/WARNING/ERROR
```

### Supported Languages

<details>
<summary>View all supported languages</summary>

| Language | Extension | Semgrep Support |
|----------|-----------|-----------------|
| Python | `.py` | ✅ Full |
| JavaScript | `.js` | ✅ Full |
| TypeScript | `.ts` | ✅ Full |
| Java | `.java` | ✅ Full |
| Go | `.go` | ✅ Full |
| PHP | `.php` | ✅ Full |
| Ruby | `.rb` | ✅ Full |
| C | `.c` | ✅ Full |
| C++ | `.cpp` | ✅ Full |
| C# | `.cs` | ✅ Full |
| Kotlin | `.kt` | ✅ Full |
| Rust | `.rs` | ✅ Full |
| Scala | `.scala` | ✅ Full |
| Swift | `.swift` | ✅ Full |

</details>

## 🐋 Docker Deployment

### Development Deployment

```bash
# Start development environment
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Production Deployment

```bash
# Deploy production setup
docker-compose -f docker-compose.prod.yml up -d

# Scale API instances
docker-compose -f docker-compose.prod.yml up -d --scale semgrep-api=3

# Monitor services
docker-compose -f docker-compose.prod.yml ps
```

### Custom Docker Build

```bash
# Build custom image
docker build -t semgrep-api:custom .

# Run with custom configuration
docker run -d \
  -p 8000:8000 \
  -e ENVIRONMENT=production \
  -v $(pwd)/logs:/app/logs \
  semgrep-api:custom
```

## 🛠️ Development

### Project Structure

```
semgrep-api/
├── 📁 app/                     # Application source code
│   ├── 📄 main.py             # FastAPI application
│   ├── 📄 config.py           # Configuration management
│   ├── 📄 models.py           # Pydantic data models
│   └── 📁 services/           # Business logic
│       └── 📄 semgrep_service.py
├── 📄 docker-compose.yml      # Docker development setup
├── 📄 docker-compose.prod.yml # Docker production setup
├── 📄 Dockerfile              # Development Docker image
├── 📄 Dockerfile.prod         # Production Docker image
├── 📄 requirements.txt        # Python dependencies
├── 📄 .env.example           # Environment template
├── 📄 setup.sh               # Project setup script
├── 📄 deploy.sh              # Deployment script
├── 📄 test.sh                # Testing script
├── 📄 run-dev.sh             # Development runner
├── 📄 Makefile               # Task automation
└── 📄 README.md              # This file
```

### Available Commands

```bash
# Setup project
make install

# Run development server
make dev

# Run tests
make test

# Build Docker images
make build

# Deploy services
make deploy

# Deploy production
make deploy-prod

# View logs
make logs

# Stop all services
make stop

# Clean temporary files
make clean
```

### Development Workflow

1. **Setup Environment**
   ```bash
   ./setup.sh
   ```

2. **Start Development**
   ```bash
   ./run-dev.sh
   ```

3. **Make Changes**
   - Edit files in `app/` directory
   - Server auto-reloads on changes

4. **Test Changes**
   ```bash
   ./test.sh
   ```

5. **Deploy**
   ```bash
   ./deploy.sh
   ```

## 🧪 Testing

### Automated Testing

```bash
# Run all tests
./test.sh

# Individual test commands
curl http://localhost:8000/health
curl -X POST http://localhost:8000/scan -H "Content-Type: application/json" -d '{"code":"print(\"test\")", "language":"python"}'
```

### Manual Testing

<details>
<summary>Example test scenarios</summary>

**Test 1: Basic Security Scan**
```bash
curl -X POST "http://localhost:8000/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "import subprocess\nsubprocess.call([\"rm\", \"-rf\", \"/\"])",
    "language": "python"
  }'
```

**Test 2: Safe Code Scan**
```bash
curl -X POST "http://localhost:8000/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "def hello():\n    print(\"Hello, World!\")",
    "language": "python"
  }'
```

**Test 3: Bulk File Scan**
```bash
curl -X POST "http://localhost:8000/scan/bulk" \
  -H "Content-Type: application/json" \
  -d '{
    "files": [
      {"filename": "test1.py", "content": "import os"},
      {"filename": "test2.js", "content": "eval(input)"}
    ]
  }'
```

</details>

### Load Testing

```bash
# Install locust
pip install locust

# Run load tests
locust -f tests/load_test.py --host=http://localhost:8000
```

## 📊 Monitoring

### Health Monitoring

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `/health` | Service health | Status, version, uptime |
| `/` | API info | Endpoints, documentation |
| `/docs` | Interactive docs | Swagger UI |

### Logging

```bash
# Application logs
tail -f logs/app.log

# Docker container logs
docker-compose logs -f

# Real-time monitoring
docker-compose logs -f semgrep-api
```

### Metrics Collection

The API automatically collects:
- Request processing time
- Success/failure rates
- Memory usage
- Scan statistics
- Error frequencies

## 🔒 Security

### Security Features

- **Input Validation**: Pydantic models validate all inputs
- **File Size Limits**: Configurable maximum file sizes
- **Request Rate Limiting**: Prevent abuse
- **Non-root Containers**: Enhanced container security
- **Dependency Scanning**: Regular security updates

### Security Configuration

```bash
# Enable API key authentication
API_KEY=your-secure-api-key

# Set strong secret key
SECRET_KEY=your-very-secure-secret-key-minimum-32-characters

# Configure limits
MAX_FILE_SIZE=10485760        # 10MB
MAX_FILES_PER_REQUEST=50
SEMGREP_TIMEOUT=300
```

### Authentication (Optional)

Add API key to requests:
```bash
curl -H "X-API-Key: your-api-key" http://localhost:8000/scan
```

## 🚀 Production Deployment

### Server Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4GB | 8GB+ |
| Storage | 10GB | 50GB+ |
| OS | Linux | Ubuntu 20.04+ |

### Production Checklist

- [ ] Set `ENVIRONMENT=production`
- [ ] Configure strong `SECRET_KEY`
- [ ] Set up reverse proxy (Nginx)
- [ ] Configure SSL certificates
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure log rotation
- [ ] Set up automated backups
- [ ] Configure firewall rules
- [ ] Set up CI/CD pipeline

### Scaling

<details>
<summary>Horizontal scaling examples</summary>

**Scale API instances:**
```bash
docker-compose -f docker-compose.prod.yml up -d --scale semgrep-api=5
```

**Load balancer configuration:**
```nginx
upstream semgrep_api {
    server localhost:8000;
    server localhost:8001;
    server localhost:8002;
}

server {
    listen 80;
    location / {
        proxy_pass http://semgrep_api;
    }
}
```

</details>

### Cloud Deployment

<details>
<summary>Cloud platform examples</summary>

**AWS ECS:**
```bash
# Build and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
docker build -t semgrep-api .
docker tag semgrep-api:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/semgrep-api:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/semgrep-api:latest
```

**Google Cloud Run:**
```bash
gcloud run deploy semgrep-api --source . --platform managed --region us-central1
```

**Azure Container Instances:**
```bash
az container create --resource-group myResourceGroup --name semgrep-api --image semgrep-api:latest
```

</details>

## 🆘 Troubleshooting

### Common Issues

<details>
<summary>Docker permission denied</summary>

**Problem:** `Permission denied` when running Docker commands

**Solution:**
```bash
sudo usermod -aG docker $USER
newgrp docker
# Or logout and login again
```

</details>

<details>
<summary>Semgrep timeout errors</summary>

**Problem:** Scans timing out on large files

**Solution:**
```bash
# Increase timeout in .env
SEMGREP_TIMEOUT=600

# Or pass as environment variable
docker-compose up -d -e SEMGREP_TIMEOUT=600
```

</details>

<details>
<summary>Memory issues</summary>

**Problem:** Out of memory errors during scanning

**Solution:**
```bash
# Increase memory limit
SEMGREP_MAX_MEMORY=8192

# Monitor memory usage
docker stats
```

</details>

<details>
<summary>Port conflicts</summary>

**Problem:** Port 8000 already in use

**Solution:**
```bash
# Change port in docker-compose.yml
ports:
  - "8001:8000"
```

</details>

### Debug Mode

```bash
# Enable debug logging
export DEBUG=true
export LOG_LEVEL=DEBUG

# Restart with debug
./run-dev.sh
```

### Getting Help

1. **Check Documentation**: Visit `/docs` endpoint
2. **Review Logs**: Use `docker-compose logs -f`
3. **Health Check**: Test `/health` endpoint
4. **Run Tests**: Execute `./test.sh`
5. **Create Issue**: Submit GitHub issue with logs

## 🤝 Contributing

We welcome contributions! Please follow these steps:

### How to Contribute

1. **Fork the Repository**
   ```bash
   git clone https://github.com/yourusername/semgrep-api.git
   cd semgrep-api
   ```

2. **Create Feature Branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

3. **Make Changes**
   - Add new features
   - Fix bugs
   - Improve documentation
   - Add tests

4. **Test Changes**
   ```bash
   ./setup.sh
   ./test.sh
   ```

5. **Commit Changes**
   ```bash
   git commit -m "Add amazing feature"
   ```

6. **Push and Create PR**
   ```bash
   git push origin feature/amazing-feature
   ```

### Development Guidelines

- Follow PEP 8 style guide
- Add tests for new features
- Update documentation
- Use meaningful commit messages
- Keep PRs focused and small

### Code Style

```bash
# Format code
black app/ tests/
isort app/ tests/

# Lint code
flake8 app/ tests/

# Type checking
mypy app/
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 Semgrep API Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

<div align="center">

### ⭐ Star this repository if it helped you!

[![GitHub stars](https://img.shields.io/github/stars/yourusername/semgrep-api?style=social)](https://github.com/yourusername/semgrep-api/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/yourusername/semgrep-api?style=social)](https://github.com/yourusername/semgrep-api/network/members)
[![GitHub issues](https://img.shields.io/github/issues/yourusername/semgrep-api)](https://github.com/yourusername/semgrep-api/issues)

**Made with ❤️ by the community**

[Report Bug](https://github.com/yourusername/semgrep-api/issues) • [Request Feature](https://github.com/yourusername/semgrep-api/issues) • [Documentation](https://github.com/yourusername/semgrep-api/wiki)

</div>