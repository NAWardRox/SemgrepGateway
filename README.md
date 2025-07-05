# Semgrep API

A simple REST API for code security scanning using Semgrep.

## Quick Start

```bash
# Clone and setup
git clone https://github.com/your-username/semgrep-api.git
cd semgrep-api
chmod +x *.sh && ./setup.sh

# Deploy
./deploy.sh
```

API will be available at: http://localhost:8000

## Usage

### Scan code snippet

```bash
curl -X POST "http://localhost:8000/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "import os\nos.system(\"rm -rf /\")",
    "language": "python"
  }'
```

### Bulk scan multiple files

```bash
curl -X POST "http://localhost:8000/scan/bulk" \
  -H "Content-Type: application/json" \
  -d '{
    "files": [
      {"filename": "app.py", "content": "import subprocess\nsubprocess.call([\"ls\"])"}
    ]
  }'
```

### Upload files for scanning

```bash
curl -X POST "http://localhost:8000/scan/upload" \
  -F "files=@script.py"
```

### Health check

```bash
curl http://localhost:8000/health
```

## Local Development

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
cp .env.example .env

# Run development server
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API Documentation

- Interactive docs: http://localhost:8000/docs
- OpenAPI spec: http://localhost:8000/openapi.json

## License

MIT License - see [LICENSE](LICENSE) file for details.