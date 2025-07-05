# Add these updated endpoints to app/main.py

@app.get("/rules")
async def get_rules():
    """Get available Semgrep rules and configurations"""
    try:
        # Get popular/recommended configs
        popular_configs = [
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
            "p/csharp"
        ]

        # Get custom rules from filesystem
        custom_rules = []
        custom_rules_dir = "rules/custom"

        if os.path.exists(custom_rules_dir):
            for file in os.listdir(custom_rules_dir):
                if file.endswith(('.yml', '.yaml')):
                    rule_path = f"{custom_rules_dir}/{file}"
                    custom_rules.append({
                        "name": file,
                        "path": rule_path,
                        "size": os.path.getsize(rule_path) if os.path.exists(rule_path) else 0
                    })

        # Try to get registry rules (with fallback)
        registry_rules = []
        try:
            registry_rules = await semgrep_service.get_available_rules()
        except Exception as e:
            logger.warning(f"Could not fetch registry rules: {e}")
            # Fallback to known popular rules
            registry_rules = popular_configs[:10]  # First 10 as sample

        return {
            "status": "success",
            "popular_configs": popular_configs,
            "custom_rules": custom_rules,
            "registry_rules": registry_rules[:20] if registry_rules else [],
            "total_custom": len(custom_rules),
            "total_registry": len(registry_rules) if registry_rules else 0,
            "recommended": {
                "security": ["p/security-audit", "p/owasp-top-ten", "p/cwe-top-25"],
                "languages": ["p/python", "p/javascript", "p/java", "p/go"],
                "frameworks": [
                    "r/python.django.security",
                    "r/python.flask.security",
                    "r/javascript.express.security"
                ],
                "custom": [rule["path"] for rule in custom_rules]
            }
        }

    except Exception as e:
        logger.error(f"Failed to get rules: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve rules: {str(e)}")


@app.get("/rules/test")
async def test_rules():
    """Test if rules are working properly"""
    try:
        test_results = {}

        # Test popular configs
        popular_configs = ["auto", "p/security-audit", "p/python"]

        for config in popular_configs:
            try:
                # Create a simple test request
                test_request = ScanRequest(
                    code="import os\nos.system('ls')",
                    language="python",
                    config=config
                )

                # Run scan
                result = await semgrep_service.scan_code(test_request)

                test_results[config] = {
                    "status": "working",
                    "findings_count": len(result.findings),
                    "has_findings": len(result.findings) > 0,
                    "errors": result.errors
                }

            except Exception as e:
                test_results[config] = {
                    "status": "error",
                    "error": str(e)
                }

        # Test custom rules
        custom_rules_dir = "rules/custom"
        if os.path.exists(custom_rules_dir):
            for file in os.listdir(custom_rules_dir):
                if file.endswith(('.yml', '.yaml')):
                    rule_path = f"{custom_rules_dir}/{file}"
                    try:
                        test_request = ScanRequest(
                            code="password = 'admin123'\nos.system('ls')",
                            language="python",
                            config=rule_path
                        )

                        result = await semgrep_service.scan_code(test_request)

                        test_results[f"custom/{file}"] = {
                            "status": "working",
                            "findings_count": len(result.findings),
                            "has_findings": len(result.findings) > 0
                        }

                    except Exception as e:
                        test_results[f"custom/{file}"] = {
                            "status": "error",
                            "error": str(e)
                        }

        return {
            "status": "success",
            "test_results": test_results,
            "summary": {
                "total_tested": len(test_results),
                "working": len([r for r in test_results.values() if r.get("status") == "working"]),
                "errors": len([r for r in test_results.values() if r.get("status") == "error"])
            }
        }

    except Exception as e:
        logger.error(f"Rules test failed: {e}")
        raise HTTPException(status_code=500, detail=f"Rules test failed: {str(e)}")


@app.get("/rules/custom")
async def get_custom_rules():
    """Get detailed information about custom rules"""
    try:
        custom_rules = []
        custom_rules_dir = "rules/custom"

        if not os.path.exists(custom_rules_dir):
            return {
                "status": "success",
                "custom_rules": [],
                "message": "No custom rules directory found"
            }

        for file in os.listdir(custom_rules_dir):
            if file.endswith(('.yml', '.yaml')):
                rule_path = os.path.join(custom_rules_dir, file)

                try:
                    # Read rule file content
                    with open(rule_path, 'r') as f:
                        content = f.read()

                    # Parse YAML to count rules
                    import yaml
                    rule_data = yaml.safe_load(content)
                    rule_count = len(rule_data.get('rules', [])) if rule_data else 0

                    # Get rule IDs
                    rule_ids = []
                    if rule_data and 'rules' in rule_data:
                        rule_ids = [rule.get('id', 'unknown') for rule in rule_data['rules']]

                    custom_rules.append({
                        "filename": file,
                        "path": f"rules/custom/{file}",
                        "size": os.path.getsize(rule_path),
                        "rule_count": rule_count,
                        "rule_ids": rule_ids,
                        "modified": os.path.getmtime(rule_path)
                    })

                except Exception as e:
                    custom_rules.append({
                        "filename": file,
                        "path": f"rules/custom/{file}",
                        "error": f"Failed to parse: {str(e)}"
                    })

        return {
            "status": "success",
            "custom_rules": custom_rules,
            "total_files": len(custom_rules),
            "total_rules": sum(rule.get('rule_count', 0) for rule in custom_rules)
        }

    except Exception as e:
        logger.error(f"Failed to get custom rules: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/rules/popular")
async def get_popular_rules():
    """Get popular/recommended rule configurations"""
    return {
        "status": "success",
        "popular_rules": {
            "security_focused": [
                {
                    "config": "p/security-audit",
                    "description": "Comprehensive security audit rules",
                    "languages": ["python", "javascript", "java", "go", "php", "ruby"],
                    "recommended_for": "General security scanning"
                },
                {
                    "config": "p/owasp-top-ten",
                    "description": "OWASP Top 10 vulnerability patterns",
                    "languages": ["python", "javascript", "java", "php"],
                    "recommended_for": "Web application security"
                },
                {
                    "config": "p/cwe-top-25",
                    "description": "CWE Top 25 most dangerous software errors",
                    "languages": ["python", "javascript", "java", "c", "cpp"],
                    "recommended_for": "Critical vulnerability detection"
                }
            ],
            "language_specific": [
                {
                    "config": "p/python",
                    "description": "Python-specific security and quality rules",
                    "languages": ["python"],
                    "recommended_for": "Python applications"
                },
                {
                    "config": "p/javascript",
                    "description": "JavaScript/Node.js security rules",
                    "languages": ["javascript", "typescript"],
                    "recommended_for": "JavaScript applications"
                },
                {
                    "config": "p/java",
                    "description": "Java security and quality rules",
                    "languages": ["java"],
                    "recommended_for": "Java applications"
                }
            ],
            "framework_specific": [
                {
                    "config": "r/python.django.security",
                    "description": "Django framework security rules",
                    "languages": ["python"],
                    "recommended_for": "Django web applications"
                },
                {
                    "config": "r/javascript.express.security",
                    "description": "Express.js security rules",
                    "languages": ["javascript"],
                    "recommended_for": "Express.js applications"
                }
            ]
        },
        "usage_examples": {
            "auto_detection": {
                "config": "auto",
                "description": "Automatically select appropriate rules based on detected languages"
            },
            "custom_rules": {
                "config": "rules/custom/security-essentials.yml",
                "description": "Use custom security rules created during deployment"
            }
        }
    }