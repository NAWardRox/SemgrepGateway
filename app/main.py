from fastapi import FastAPI, HTTPException, Depends, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import time
import logging
from typing import List, Optional
import asyncio

from app.config import get_settings
from app.models import ScanRequest, ScanResult, BulkScanRequest, HealthCheck
from app.services.semgrep_service import semgrep_service

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Get settings
settings = get_settings()

# Create FastAPI app
app = FastAPI(
    title="Semgrep API",
    version="2.0.0",
    description="Production-ready Semgrep code security scanning API",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request logging middleware
@app.middleware("http")
async def log_requests(request, call_next):
    start_time = time.time()
    logger.info(f"Request: {request.method} {request.url}")

    response = await call_next(request)

    process_time = time.time() - start_time
    logger.info(f"Response: {response.status_code} - {process_time:.4f}s")
    response.headers["X-Process-Time"] = str(process_time)

    return response


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc: Exception):
    logger.error(f"Global exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"message": "Internal server error", "detail": str(exc)}
    )


# Root endpoint
@app.get("/")
async def root():
    return {
        "message": "Semgrep API v2.0.0",
        "docs": "/docs" if settings.debug else "disabled",
        "endpoints": [
            "/scan - Scan single code snippet",
            "/scan/bulk - Scan multiple files",
            "/scan/upload - Upload and scan files",
            "/health - Health check",
            "/rules - Available rules"
        ]
    }


# Health check
@app.get("/health", response_model=HealthCheck)
async def health_check():
    """Health check endpoint"""
    try:
        semgrep_version = await semgrep_service.get_version()
        return HealthCheck(
            status="healthy",
            timestamp=time.time(),
            version="2.0.0",
            semgrep_version=semgrep_version
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return HealthCheck(
            status="unhealthy",
            timestamp=time.time(),
            version="2.0.0"
        )


# Single scan endpoint
@app.post("/scan", response_model=ScanResult)
async def scan_code(request: ScanRequest):
    """Scan a single code snippet"""
    try:
        start_time = time.time()
        result = await semgrep_service.scan_code(request)
        result.execution_time = time.time() - start_time
        return result
    except Exception as e:
        logger.error(f"Scan failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Bulk scan endpoint
@app.post("/scan/bulk", response_model=ScanResult)
async def bulk_scan(request: BulkScanRequest):
    """Scan multiple files"""
    try:
        if len(request.files) > settings.max_files_per_request:
            raise HTTPException(
                status_code=400,
                detail=f"Too many files. Max: {settings.max_files_per_request}"
            )

        start_time = time.time()
        result = await semgrep_service.scan_multiple_files(request.files, request.config)
        result.execution_time = time.time() - start_time
        return result
    except Exception as e:
        logger.error(f"Bulk scan failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Upload scan endpoint
@app.post("/scan/upload", response_model=ScanResult)
async def upload_scan(files: List[UploadFile] = File(...), config: Optional[str] = None):
    """Upload and scan files"""
    try:
        if len(files) > settings.max_files_per_request:
            raise HTTPException(
                status_code=400,
                detail=f"Too many files. Max: {settings.max_files_per_request}"
            )

        # Convert uploads to file data
        file_data = []
        for file in files:
            if file.size > settings.max_file_size:
                raise HTTPException(
                    status_code=400,
                    detail=f"File {file.filename} too large. Max: {settings.max_file_size} bytes"
                )

            content = await file.read()
            file_data.append({
                "filename": file.filename,
                "content": content.decode('utf-8', errors='ignore')
            })

        start_time = time.time()
        result = await semgrep_service.scan_multiple_files(file_data, config)
        result.execution_time = time.time() - start_time
        return result

    except Exception as e:
        logger.error(f"Upload scan failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Rules endpoint
@app.get("/rules")
async def get_rules():
    """Get available Semgrep rules"""
    try:
        rules = await semgrep_service.get_available_rules()
        return {"rules": rules}
    except Exception as e:
        logger.error(f"Failed to get rules: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.reload,
        log_level=settings.log_level.lower()
    )