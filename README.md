# Semgrep API

Deploy:

```bash
git clone <repo> && cd semgrep-api
./deploy.sh
````

## Usage
```
# Scan code
curl -X POST http://localhost:8000/scan \
  -H "Content-Type: application/json" \
  -d '{"code": "print(\"hello\")", "language": "python"}'
```
# Health check
```
curl http://localhost:8000/health
```
# Docs
```
open http://localhost:8000/docs
```

## Commands
- `./deploy.sh` - Deploy
- `./test.sh` - Test API  
- `docker-compose logs -f` - View logs
- `docker-compose down` - Stop


## Final Project Structure
```
semgrep-api/
├── main.py              # Core API (50 lines)
├── Dockerfile           # Simple build (8 lines) 
├── docker-compose.yml   # Easy deploy (8 lines)
├── setup.sh            # Auto setup (15 lines)
├── deploy.sh           # One-click deploy (20 lines)
├── test.sh             # Quick test (10 lines)
└── README.md           # Usage guide
```
---

## Start

```bash
# Copy files above → save to folder
chmod +x *.sh
./deploy.sh
```

**API running at http://localhost:8000**