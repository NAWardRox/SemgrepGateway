FROM python:3.9-slim

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN pip install fastapi uvicorn semgrep

WORKDIR /app
COPY main.py .

EXPOSE 8000
HEALTHCHECK CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]