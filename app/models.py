from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any
from enum import Enum


class SeverityLevel(str, Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"


class ScanRequest(BaseModel):
    code: str = Field(..., min_length=1, max_length=1000000, description="Code to scan")
    language: str = Field(..., min_length=1, max_length=50, description="Programming language")
    rules: Optional[List[str]] = Field(None, max_items=50, description="Custom rules")
    config: Optional[str] = Field(None, max_length=200, description="Semgrep config")

    @validator('language')
    def validate_language(cls, v):
        supported_languages = {
            'python', 'javascript', 'typescript', 'java', 'go', 'php',
            'ruby', 'c', 'cpp', 'csharp', 'kotlin', 'rust', 'scala', 'swift', 'auto'
        }
        if v.lower() not in supported_languages:
            raise ValueError(f"Language '{v}' not supported. Supported: {', '.join(supported_languages)}")
        return v.lower()

    class Config:
        schema_extra = {
            "example": {
                "code": "import os\nos.system('ls')",
                "language": "python",
                "config": "auto"
            }
        }


class BulkScanRequest(BaseModel):
    files: List[Dict[str, str]] = Field(..., min_items=1, max_items=50, description="Files to scan")
    config: Optional[str] = Field(None, max_length=200, description="Semgrep config")

    @validator('files')
    def validate_files(cls, v):
        for i, file_data in enumerate(v):
            if 'filename' not in file_data or 'content' not in file_data:
                raise ValueError(f"File {i}: Each file must have 'filename' and 'content' fields")
            if not file_data['filename'].strip():
                raise ValueError(f"File {i}: filename cannot be empty")
            if len(file_data['content']) > 10 * 1024 * 1024:  # 10MB
                raise ValueError(f"File {file_data['filename']}: content too large (max 10MB)")
        return v

    class Config:
        schema_extra = {
            "example": {
                "files": [
                    {
                        "filename": "app.py",
                        "content": "import subprocess\nsubprocess.call(['ls'])"
                    },
                    {
                        "filename": "script.js",
                        "content": "eval(user_input)"
                    }
                ],
                "config": "auto"
            }
        }


class ScanResult(BaseModel):
    findings: List[Dict[str, Any]] = Field(default_factory=list, description="Security findings")
    errors: List[str] = Field(default_factory=list, description="Scan errors")
    stats: Dict[str, Any] = Field(default_factory=dict, description="Scan statistics")
    execution_time: float = Field(default=0.0, description="Execution time in seconds")
    files_scanned: List[str] = Field(default_factory=list, description="Files that were scanned")

    class Config:
        schema_extra = {
            "example": {
                "findings": [
                    {
                        "rule_id": "python.lang.security.dangerous-subprocess-use",
                        "message": "Found subprocess function used with user input",
                        "severity": "ERROR",
                        "line": 2,
                        "column": 1,
                        "file": "app.py"
                    }
                ],
                "errors": [],
                "stats": {
                    "total_files": 1,
                    "total_findings": 1
                },
                "execution_time": 0.45,
                "files_scanned": ["app.py"]
            }
        }


class HealthCheck(BaseModel):
    status: str = Field(..., description="Service status")
    timestamp: float = Field(..., description="Timestamp")
    version: str = Field(..., description="API version")
    semgrep_version: Optional[str] = Field(None, description="Semgrep version")
    uptime: float = Field(default=0.0, description="Service uptime in seconds")

    class Config:
        schema_extra = {
            "example": {
                "status": "healthy",
                "timestamp": 1634567890.123,
                "version": "2.0.0",
                "semgrep_version": "1.45.0",
                "uptime": 3600.0
            }
        }


class APIResponse(BaseModel):
    success: bool = Field(default=True, description="Success status")
    message: str = Field(default="Success", description="Response message")
    data: Optional[Any] = Field(None, description="Response data")
    errors: Optional[List[str]] = Field(None, description="Error messages")


class RuleInfo(BaseModel):
    id: str = Field(..., description="Rule ID")
    name: str = Field(..., description="Rule name")
    description: Optional[str] = Field(None, description="Rule description")
    severity: SeverityLevel = Field(..., description="Rule severity")
    language: str = Field(..., description="Target language")


class ScanStats(BaseModel):
    total_files: int = Field(default=0, description="Total files scanned")
    total_findings: int = Field(default=0, description="Total findings")
    execution_time: float = Field(default=0.0, description="Total execution time")
    rules_applied: int = Field(default=0, description="Number of rules applied")
    files_with_findings: int = Field(default=0, description="Files with findings")


class Finding(BaseModel):
    rule_id: str = Field(..., description="Rule that triggered")
    message: str = Field(..., description="Finding message")
    severity: str = Field(..., description="Finding severity")
    file_path: str = Field(..., description="File path")
    start_line: int = Field(..., description="Start line number")
    end_line: int = Field(..., description="End line number")
    start_col: int = Field(..., description="Start column")
    end_col: int = Field(..., description="End column")
    code_snippet: Optional[str] = Field(None, description="Code snippet")


# Additional models for extended functionality
class CustomRule(BaseModel):
    id: str = Field(..., min_length=1, max_length=100, description="Rule ID")
    pattern: str = Field(..., min_length=1, max_length=1000, description="Semgrep pattern")
    language: str = Field(..., min_length=1, max_length=50, description="Target language")
    message: str = Field(..., min_length=1, max_length=500, description="Rule message")
    severity: SeverityLevel = Field(default=SeverityLevel.INFO, description="Rule severity")

    @validator('id')
    def validate_id(cls, v):
        if not v.replace('_', '').replace('-', '').replace('.', '').isalnum():
            raise ValueError("Rule ID must contain only alphanumeric characters, hyphens, underscores, and dots")
        return v

    class Config:
        schema_extra = {
            "example": {
                "id": "custom.dangerous.eval",
                "pattern": "eval($X)",
                "language": "javascript",
                "message": "Dangerous use of eval() function",
                "severity": "ERROR"
            }
        }


class RulesResponse(BaseModel):
    rules: List[str] = Field(..., description="Available Semgrep rules")
    total: int = Field(..., description="Total number of rules")

    class Config:
        schema_extra = {
            "example": {
                "rules": [
                    "p/python",
                    "p/javascript",
                    "r/python.django.security",
                    "r/javascript.express.security"
                ],
                "total": 150
            }
        }