# Simplified Dockerfile - Rules handled by volume mount

FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Install Semgrep
RUN pip install --no-cache-dir semgrep

# Pre-download popular rules (cached in image)
RUN echo "Pre-downloading popular Semgrep rules..." \
    && semgrep --config=p/security-audit --dry-run /tmp >/dev/null 2>&1 || true \
    && semgrep --config=p/python --dry-run /tmp >/dev/null 2>&1 || true \
    && semgrep --config=p/javascript --dry-run /tmp >/dev/null 2>&1 || true \
    && semgrep --config=auto --dry-run /tmp >/dev/null 2>&1 || true \
    && echo "✅ Rules pre-downloaded and cached"

# Copy application
COPY app/ app/

# Create base directories (rules will be mounted as volume)
RUN mkdir -p logs rules

# Verify Semgrep installation
RUN semgrep --version

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]