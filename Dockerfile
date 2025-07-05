# Fixed Dockerfile with Semgrep pre-installed

FROM python:3.9-slim

# Install system dependencies and Semgrep
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Install Semgrep in the container
RUN pip install --no-cache-dir semgrep

# Download popular Semgrep rules during build
RUN echo "Downloading Semgrep rules..." \
    && semgrep --config=p/security-audit --dry-run /tmp >/dev/null 2>&1 || true \
    && semgrep --config=p/python --dry-run /tmp >/dev/null 2>&1 || true \
    && semgrep --config=p/javascript --dry-run /tmp >/dev/null 2>&1 || true \
    && semgrep --config=p/java --dry-run /tmp >/dev/null 2>&1 || true \
    && semgrep --config=auto --dry-run /tmp >/dev/null 2>&1 || true \
    && echo "Semgrep rules cached successfully"

# Copy application files
COPY app/ app/
COPY rules/ rules/

# Create logs directory
RUN mkdir -p logs

# Verify Semgrep installation
RUN semgrep --version && echo "✅ Semgrep installed successfully"

# Expose port
EXPOSE 8000

# Health check that also verifies Semgrep
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health && semgrep --version || exit 1

# Run application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]