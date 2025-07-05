# Dockerfile - Always Install Latest Semgrep

FROM python:3.9-slim

# Set build arguments for version control
ARG SEMGREP_VERSION=latest
ARG BUILD_DATE
ARG VCS_REF

# Labels for metadata
LABEL maintainer="your-email@domain.com" \
      description="Semgrep API with latest Semgrep version" \
      version="2.0.0" \
      build-date="$BUILD_DATE" \
      vcs-ref="$VCS_REF"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Upgrade pip and install base requirements
RUN pip install --no-cache-dir --upgrade pip

# Install Semgrep - Always get latest unless version specified
RUN if [ "$SEMGREP_VERSION" = "latest" ]; then \
        echo "📦 Installing latest Semgrep..." && \
        pip install --no-cache-dir --upgrade semgrep; \
    else \
        echo "📦 Installing Semgrep version $SEMGREP_VERSION..." && \
        pip install --no-cache-dir semgrep==$SEMGREP_VERSION; \
    fi

# Verify installation and show version
RUN echo "✅ Semgrep installed:" && semgrep --version

# Install other Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download and cache Semgrep rules (with better error handling)
RUN echo "📦 Pre-downloading Semgrep rules..." \
    && mkdir -p /tmp/rule_download \
    && echo "# Test file for rule download" > /tmp/rule_download/test.py \
    && (timeout 180 semgrep --config=p/security-audit /tmp/rule_download/ --json >/dev/null 2>&1 && echo "✅ security-audit rules cached" || echo "⚠️ security-audit rules failed") \
    && (timeout 180 semgrep --config=p/owasp-top-ten /tmp/rule_download/ --json >/dev/null 2>&1 && echo "✅ owasp-top-ten rules cached" || echo "⚠️ owasp-top-ten rules failed") \
    && (timeout 180 semgrep --config=p/cwe-top-25 /tmp/rule_download/ --json >/dev/null 2>&1 && echo "✅ cwe-top-25 rules cached" || echo "⚠️ cwe-top-25 rules failed") \
    && (timeout 180 semgrep --config=p/python /tmp/rule_download/ --json >/dev/null 2>&1 && echo "✅ python rules cached" || echo "⚠️ python rules failed") \
    && (timeout 180 semgrep --config=p/javascript /tmp/rule_download/ --json >/dev/null 2>&1 && echo "✅ javascript rules cached" || echo "⚠️ javascript rules failed") \
    && (timeout 180 semgrep --config=p/java /tmp/rule_download/ --json >/dev/null 2>&1 && echo "✅ java rules cached" || echo "⚠️ java rules failed") \
    && rm -rf /tmp/rule_download \
    && echo "📋 Rule download completed"

# Copy application files
COPY app/ app/

# Create necessary directories
RUN mkdir -p logs rules/custom rules/downloaded

# Create entrypoint script for runtime rule updates
RUN echo '#!/bin/bash' > /usr/local/bin/update-semgrep.sh \
    && echo 'echo "Updating Semgrep to latest..."' >> /usr/local/bin/update-semgrep.sh \
    && echo 'pip install --upgrade semgrep' >> /usr/local/bin/update-semgrep.sh \
    && echo 'echo "New version: $(semgrep --version)"' >> /usr/local/bin/update-semgrep.sh \
    && echo 'echo "Clearing cache..."' >> /usr/local/bin/update-semgrep.sh \
    && echo 'rm -rf ~/.semgrep/cache 2>/dev/null || true' >> /usr/local/bin/update-semgrep.sh \
    && chmod +x /usr/local/bin/update-semgrep.sh

# Show final setup info
RUN echo "📋 Final setup:" \
    && echo "Semgrep version: $(semgrep --version)" \
    && echo "Python version: $(python --version)" \
    && echo "Available rule configs (first 10):" \
    && (semgrep --list-configs | head -10 || echo "Rules will be available at runtime") \
    && echo "Cache location: ~/.semgrep" \
    && echo "Update command available: /usr/local/bin/update-semgrep.sh"

# Expose port
EXPOSE 8000

# Enhanced health check
HEALTHCHECK --interval=30s --timeout=15s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health && \
        semgrep --version >/dev/null && \
        echo "Health check passed" || exit 1

# Set environment variables
ENV SEMGREP_CACHE_DIR=/root/.semgrep
ENV SEMGREP_VERSION_CHECK_TIMEOUT=10

# Run application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]