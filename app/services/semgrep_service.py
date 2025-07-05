# Update this method in app/services/semgrep_service.py

async def get_available_rules(self) -> List[str]:
    """Get list of available Semgrep rules with fallback"""
    try:
        result = await asyncio.get_event_loop().run_in_executor(
            self.executor,
            self._run_command,
            ["semgrep", "--list-configs"]
        )

        if result.returncode == 0 and result.stdout.strip():
            # Parse the output and return list of rules
            rules = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]
            return rules
        else:
            logger.warning(f"semgrep --list-configs failed: {result.stderr}")
            # Return fallback list of popular rules
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


async def test_rule_config(self, config: str) -> Dict[str, Any]:
    """Test if a rule configuration is working"""
    try:
        # Create a simple test file with known vulnerabilities
        test_code = """
import os
import subprocess
password = "admin123"
os.system("ls")
eval("print('test')")
subprocess.call("rm file", shell=True)
"""

        # Create temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(test_code)
            temp_file = f.name

        try:
            # Run semgrep with the config
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


async def get_custom_rules_info(self) -> List[Dict[str, Any]]:
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
                    # Get file stats
                    stat = os.stat(filepath)

                    # Try to parse rule count
                    rule_count = 0
                    try:
                        with open(filepath, 'r') as f:
                            content = f.read()
                            # Simple count of "- id:" patterns
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