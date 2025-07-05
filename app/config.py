from pydantic_settings import BaseSettings
from typing import Optional
import os


class Settings(BaseSettings):
    # App config
    app_name: str = "Semgrep API"
    app_version: str = "2.0.0"
    debug: bool = False

    # Server config
    host: str = "0.0.0.0"
    port: int = 8000
    reload: bool = False

    # Security
    api_key: Optional[str] = None
    secret_key: str = "your-secret-key-change-in-production"

    # Semgrep config
    semgrep_timeout: int = 300
    semgrep_max_memory: int = 4096
    max_file_size: int = 10 * 1024 * 1024  # 10MB
    max_files_per_request: int = 50

    # Logging
    log_level: str = "INFO"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


# Environment-specific configs
class DevelopmentConfig(Settings):
    debug: bool = True
    reload: bool = True
    log_level: str = "DEBUG"


class ProductionConfig(Settings):
    debug: bool = False
    reload: bool = False
    log_level: str = "WARNING"


def get_settings():
    env = os.getenv("ENVIRONMENT", "development")

    if env == "production":
        return ProductionConfig()
    elif env == "development":
        return DevelopmentConfig()
    else:
        return Settings()