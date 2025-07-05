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
            return "unknown"

    async def scan_code(self, request: ScanRequest) -> ScanResult:
        """Scan a single code snippet"""
        try:
            if len(request.code) > settings.max_file_size:
                raise ValueError(f"Code too large: {len(request.code)} bytes")

            ext = self._get_file_extension(request.language)
            with tempfile.NamedTemporaryFile(mode='w', suffix=f'.{ext}', delete=False) as f:
                f.write(request.code)
                temp_file = f.name

            try:
                result = await asyncio.get_event_loop().run_in_executor(
                    self.executor,
                    self._run_semgrep,
                    temp_file,
                    request.config,
                    request.rules
                )
                return result
            finally:
                os.unlink(temp_file)
        except Exception as e:
            logger.error(f"Error scanning code: {e}")
            raise

    async def scan_multiple_files(self, files: List[Dict[str, str]], config: Optional[str] = None) -> ScanResult:
        """Scan multiple files"""
        temp_dir = tempfile.mkdtemp()
        files_created = []

        try:
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
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

    def _run_semgrep(self, target: str, config: Optional[str], rules: Optional[List[str]]) -> ScanResult:
        """Run semgrep command"""
        try:
            cmd = ["semgrep", "--json", "--no-git-ignore", "--quiet"]

            if config:
                cmd.extend(["--config", config])
            elif rules:
                for rule in rules:
                    cmd.extend(["--config", rule])
            else:
                cmd.extend(["--config", "auto"])

            cmd.append(target)
            result = self._run_command(cmd)

            if result.returncode == 0 or result.returncode == 1:
                try:
                    output = json.loads(result.stdout) if result.stdout else {}
                except json.JSONDecodeError:
                    output = {"results": [], "errors": ["Failed to parse JSON output"]}

                return ScanResult(
                    findings=output.get("results", []),
                    errors=output.get("errors", []),
                    stats=output.get("stats", {})
                )
            else:
                return ScanResult(
                    findings=[],
                    errors=[f"Semgrep error: {result.stderr}"],
                    stats={}
                )
        except subprocess.TimeoutExpired:
            return ScanResult(
                findings=[],
                errors=[f"Scan timeout after {self.timeout} seconds"],
                stats={}
            )
        except Exception as e:
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
        """Get list of available Semgrep rules with fallback"""
        try:
            result = await asyncio.get_event_loop().run_in_executor(
                self.executor,
                self._run_command,
                ["semgrep", "--list-configs"]
            )

            if result.returncode == 0 and result.stdout.strip():
                rules = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]
                return rules
            else:
                logger.warning(f"semgrep --list-configs failed: {result.stderr}")
                return self._get_fallback_rules()

        except Exception as e:
            logger.error(f"Error getting rules: {e}")
            return self._get_fallback_rules()

    def _get_fallback_rules(self) -> List[str]:
        """Fallback list of popular/known rules"""
        return [
            "auto",
            "p/security-audit",
            "p/owasp-top-ten",
            "p/cwe-top-25",
            "p/python",
            "p/javascript",
            "p/typescript",
            "p/java",
            "p/go",
            "p/php",
            "p/ruby",
            "p/c",
            "p/cpp",
            "p/csharp",
            "p/kotlin",
            "p/rust",
            "p/scala",
            "p/swift",
            "r/python.django.security",
            "r/python.flask.security",
            "r/javascript.express.security",
            "r/javascript.node-js.security",
            "r/java.spring.security"
        ]

    async def test_rule_config(self, config: str) -> Dict[str, any]:
        """Test if a rule configuration is working"""
        try:
            test_code = """
import os
import subprocess
password = "admin123"
os.system("ls")
eval("print('test')")
subprocess.call("rm file", shell=True)
"""

            with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
                f.write(test_code)
                temp_file = f.name

            try:
                result = await asyncio.get_event_loop().run_in_executor(
                    self.executor,
                    self._run_semgrep,
                    temp_file,
                    config,
                    None
                )

                return {
                    "config": config,
                    "status": "working",
                    "findings_count": len(result.findings),
                    "has_findings": len(result.findings) > 0,
                    "errors": result.errors
                }

            finally:
                os.unlink(temp_file)

        except Exception as e:
            return {
                "config": config,
                "status": "error",
                "error": str(e)
            }

    async def get_custom_rules_info(self) -> List[Dict[str, any]]:
        """Get information about custom rules files"""
        custom_rules = []
        custom_dir = "rules/custom"

        if not os.path.exists(custom_dir):
            return custom_rules

        try:
            for filename in os.listdir(custom_dir):
                if filename.endswith(('.yml', '.yaml')):
                    filepath = os.path.join(custom_dir, filename)

                    try:
                        stat = os.stat(filepath)

                        rule_count = 0
                        try:
                            with open(filepath, 'r') as f:
                                content = f.read()
                                rule_count = content.count('- id:')
                        except:
                            rule_count = 0

                        custom_rules.append({
                            "filename": filename,
                            "path": f"rules/custom/{filename}",
                            "size": stat.st_size,
                            "modified": stat.st_mtime,
                            "rule_count": rule_count
                        })

                    except Exception as e:
                        logger.warning(f"Error reading custom rule file {filename}: {e}")

        except Exception as e:
            logger.error(f"Error scanning custom rules directory: {e}")

        return custom_rules


# Singleton instance
semgrep_service = SemgrepService()