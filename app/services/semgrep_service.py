import subprocess
import json
import tempfile
import os
import logging
from typing import List, Dict, Optional
import asyncio
from concurrent.futures import ThreadPoolExecutor

from app.config import get_settings
from app.models import ScanRequest, ScanResult

logger = logging.getLogger(__name__)
settings = get_settings()


class SemgrepService:
    def __init__(self):
        self.executor = ThreadPoolExecutor(max_workers=4)
        self.timeout = settings.semgrep_timeout
        self.max_memory = settings.semgrep_max_memory

    async def get_version(self) -> str:
        """Get Semgrep version"""
        try:
            result = await asyncio.get_event_loop().run_in_executor(
                self.executor,
                self._run_command,
                ["semgrep", "--version"]
            )
            return result.stdout.strip()
        except Exception as e:
            logger.error(f"Failed to get Semgrep version: {e}")
            raise

    async def scan_code(self, request: ScanRequest) -> ScanResult:
        """Scan a single code snippet"""
        try:
            # Validate input size
            if len(request.code) > settings.max_file_size:
                raise ValueError(f"Code too large: {len(request.code)} bytes")

            # Create temporary file
            ext = self._get_file_extension(request.language)
            with tempfile.NamedTemporaryFile(mode='w', suffix=f'.{ext}', delete=False) as f:
                f.write(request.code)
                temp_file = f.name

            try:
                # Run semgrep
                result = await asyncio.get_event_loop().run_in_executor(
                    self.executor,
                    self._run_semgrep,
                    temp_file,
                    request.config,
                    request.rules
                )
                return result

            finally:
                # Cleanup
                os.unlink(temp_file)

        except Exception as e:
            logger.error(f"Error scanning code: {e}")
            raise

    async def scan_multiple_files(self, files: List[Dict[str, str]], config: Optional[str] = None) -> ScanResult:
        """Scan multiple files"""
        temp_dir = tempfile.mkdtemp()
        files_created = []

        try:
            # Create temporary files
            for file_data in files:
                filename = file_data["filename"]
                content = file_data["content"]

                if len(content) > settings.max_file_size:
                    raise ValueError(f"File {filename} too large")

                file_path = os.path.join(temp_dir, filename)
                os.makedirs(os.path.dirname(file_path), exist_ok=True)

                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                files_created.append(filename)

            # Run semgrep on directory
            result = await asyncio.get_event_loop().run_in_executor(
                self.executor,
                self._run_semgrep,
                temp_dir,
                config,
                None
            )

            result.files_scanned = files_created
            return result

        finally:
            # Cleanup
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

    def _run_semgrep(self, target: str, config: Optional[str], rules: Optional[List[str]]) -> ScanResult:
        """Run semgrep command"""
        try:
            # Build command
            cmd = ["semgrep", "--json", "--no-git-ignore", "--quiet"]

            # Add configuration
            if config:
                cmd.extend(["--config", config])
            elif rules:
                for rule in rules:
                    cmd.extend(["--config", rule])
            else:
                cmd.extend(["--config", "auto"])

            cmd.append(target)

            # Run command
            result = self._run_command(cmd)

            # Parse output
            if result.returncode == 0 or result.returncode == 1:  # 1 = findings found
                try:
                    output = json.loads(result.stdout) if result.stdout else {}
                except json.JSONDecodeError:
                    output = {"results": [], "errors": [f"Failed to parse JSON output"]}

                return ScanResult(
                    findings=output.get("results", []),
                    errors=output.get("errors", []),
                    stats=output.get("stats", {})
                )
            else:
                logger.error(f"Semgrep failed: {result.stderr}")
                return ScanResult(
                    findings=[],
                    errors=[f"Semgrep error: {result.stderr}"],
                    stats={}
                )

        except subprocess.TimeoutExpired:
            logger.error(f"Semgrep timeout after {self.timeout}s")
            return ScanResult(
                findings=[],
                errors=[f"Scan timeout after {self.timeout} seconds"],
                stats={}
            )
        except Exception as e:
            logger.error(f"Semgrep execution error: {e}")
            return ScanResult(
                findings=[],
                errors=[f"Execution error: {str(e)}"],
                stats={}
            )

    def _run_command(self, cmd: List[str]) -> subprocess.CompletedProcess:
        """Run command with timeout"""
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=self.timeout
        )

    def _get_file_extension(self, language: str) -> str:
        """Map language to file extension"""
        extensions = {
            "python": "py",
            "javascript": "js",
            "typescript": "ts",
            "java": "java",
            "go": "go",
            "php": "php",
            "ruby": "rb",
            "c": "c",
            "cpp": "cpp",
            "csharp": "cs",
            "kotlin": "kt",
            "rust": "rs",
            "scala": "scala",
            "swift": "swift",
            "auto": "txt"
        }
        return extensions.get(language, "txt")

    async def get_available_rules(self) -> List[str]:
        """Get list of available Semgrep rules"""
        try:
            result = await asyncio.get_event_loop().run_in_executor(
                self.executor,
                self._run_command,
                ["semgrep", "--list-configs"]
            )

            if result.returncode == 0:
                return result.stdout.strip().split('\n')
            else:
                return []

        except Exception as e:
            logger.error(f"Error getting rules: {e}")
            return []


# Singleton instance
semgrep_service = SemgrepService()