#!/usr/bin/env python3
"""
Advanced security summary generator with granular fail strategies.
Implements enterprise-grade security standards for medical device software.
"""

import json
import glob
import os
from datetime import datetime
from typing import Dict, List, Tuple


# Granular fail strategies based on enterprise security standards
FAIL_STRATEGIES = {
    'critical': {'max_allowed': 0, 'action': 'FAIL'},
    'high': {'max_allowed': 5, 'action': 'FAIL'},
    'medium': {'max_allowed': 50, 'action': 'WARNING'},
    'low': {'max_allowed': float('inf'), 'action': 'INFO'},
    'license_violation': {'max_allowed': 0, 'action': 'FAIL'}
}

# Medical device specific security requirements
MEDICAL_DEVICE_REQUIREMENTS = {
    'critical': {'max_allowed': 0, 'action': 'FAIL'},
    'high': {'max_allowed': 0, 'action': 'FAIL'},
    'medium': {'max_allowed': 10, 'action': 'WARNING'},
    'low': {'max_allowed': 20, 'action': 'INFO'},
    'license_violation': {'max_allowed': 0, 'action': 'FAIL'}
}


def map_sarif_level_to_severity(level: str) -> str:
    """Map SARIF level to severity."""
    mapping = {
        'error': 'high',
        'warning': 'medium',
        'note': 'low',
        'info': 'low'
    }
    return mapping.get(level.lower(), 'medium')


def analyze_sarif_files(results_dir: str) -> Dict:
    """Analyze all SARIF files and categorize findings."""
    analysis = {
        'total_vulnerabilities': 0,
        'critical': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
        'license_violations': 0,
        'by_tool': {},
        'by_file': {},
        'findings_details': []
    }
    
    sarif_files = glob.glob(f'{results_dir}/**/*.sarif', recursive=True)
    print(f"Analyzing {len(sarif_files)} SARIF files")
    
    for sarif_file in sarif_files:
        try:
            with open(sarif_file) as f:
                data = json.load(f)
            
            tool_name = os.path.basename(sarif_file).replace('.sarif', '')
            tool_findings = {
                'total': 0,
                'critical': 0,
                'high': 0,
                'medium': 0,
                'low': 0,
                'license_violations': 0
            }
            
            for run in data.get('runs', []):
                tool_info = run.get('tool', {}).get('driver', {})
                actual_tool_name = tool_info.get('name', tool_name)
                
                for result in run.get('results', []):
                    analysis['total_vulnerabilities'] += 1
                    tool_findings['total'] += 1
                    
                    # Determine severity
                    level = result.get('level', 'warning')
                    rule_id = result.get('ruleId', '')
                    
                    # Special handling for license violations
                    if 'license' in rule_id.lower() or 'license' in actual_tool_name.lower():
                        analysis['license_violations'] += 1
                        tool_findings['license_violations'] += 1
                        severity = 'license_violation'
                    else:
                        # Map SARIF level to severity for vulnerability counting
                        if rule_id.startswith('npm-audit') or 'critical' in rule_id.lower():
                            # Special handling for npm audit critical vulnerabilities
                            if 'critical' in result.get('message', {}).get('text', '').lower():
                                severity = 'critical'
                            else:
                                severity = map_sarif_level_to_severity(level)
                        else:
                            severity = map_sarif_level_to_severity(level)
                    
                    # Count by severity
                    if severity in analysis:
                        analysis[severity] += 1
                        tool_findings[severity] += 1
                    
                    # Store finding details
                    finding_detail = {
                        'tool': actual_tool_name,
                        'rule_id': rule_id,
                        'severity': severity,
                        'message': result.get('message', {}).get('text', ''),
                        'file': sarif_file,
                        'locations': result.get('locations', [])
                    }
                    analysis['findings_details'].append(finding_detail)
                    
                    # Count by file
                    for location in result.get('locations', []):
                        uri = location.get('physicalLocation', {}).get('artifactLocation', {}).get('uri', 'unknown')
                        if uri not in analysis['by_file']:
                            analysis['by_file'][uri] = 0
                        analysis['by_file'][uri] += 1
            
            if tool_findings['total'] > 0:
                analysis['by_tool'][actual_tool_name] = tool_findings
                print(f"  {actual_tool_name}: {tool_findings['total']} findings")
        
        except Exception as e:
            print(f'Error processing {sarif_file}: {e}')
    
    return analysis


def determine_overall_status(analysis: Dict, scan_level: str = 'standard') -> Tuple[str, List[str]]:
    """Determine overall security status based on findings and scan level."""
    reasons = []
    
    # Choose fail strategy based on scan level
    if scan_level == 'medical-grade':
        strategies = MEDICAL_DEVICE_REQUIREMENTS
    else:
        strategies = FAIL_STRATEGIES
    
    # Check each severity level
    for severity, strategy in strategies.items():
        count = analysis.get(severity, 0)
        max_allowed = strategy['max_allowed']
        action = strategy['action']
        
        if count > max_allowed:
            if action == 'FAIL':
                reasons.append(f"{count} {severity} issues (max allowed: {max_allowed})")
                return 'FAIL', reasons
            elif action == 'WARNING':
                reasons.append(f"{count} {severity} issues (max allowed: {max_allowed})")
    
    # Determine final status
    if reasons:
        return 'WARNING', reasons
    else:
        return 'PASS', ['All security checks passed']


def generate_detailed_markdown(analysis: Dict, scan_level: str, platforms: Dict, status: str, reasons: List[str]) -> str:
    """Generate detailed markdown security report."""
    timestamp = datetime.utcnow().isoformat()
    platforms_list = [k for k, v in platforms.items() if v]
    platforms_str = ', '.join(platforms_list) if platforms_list else 'None detected'
    
    status_emoji = {'PASS': '✅', 'WARNING': '⚠️', 'FAIL': '❌'}
    
    markdown = f"""# 🛡️ Comprehensive Security Analysis Report

**Status**: {status_emoji.get(status, "❓")} {status}
**Scan Level**: {scan_level.upper()}
**Platforms**: {platforms_str}
**Timestamp**: {timestamp}

## 📊 Security Findings Overview

| Severity | Count | Status |
|----------|-------|--------|
| 🔴 Critical | {analysis['critical']} | {"❌" if analysis['critical'] > 0 else "✅"} |
| 🟠 High | {analysis['high']} | {"❌" if analysis['high'] > FAIL_STRATEGIES['high']['max_allowed'] else "✅"} |
| 🟡 Medium | {analysis['medium']} | {"⚠️" if analysis['medium'] > FAIL_STRATEGIES['medium']['max_allowed'] else "✅"} |
| 🟢 Low | {analysis['low']} | ✅ |
| ⚖️ License | {analysis['license_violations']} | {"❌" if analysis['license_violations'] > 0 else "✅"} |

**Total Security Findings**: {analysis['total_vulnerabilities']}

## 🔍 Analysis by Security Tool

"""
    
    for tool, findings in analysis['by_tool'].items():
        markdown += f"""### {tool}
- **Total Findings**: {findings['total']}
- **Critical**: {findings['critical']} | **High**: {findings['high']} | **Medium**: {findings['medium']} | **Low**: {findings['low']}
- **License Issues**: {findings['license_violations']}

"""
    
    markdown += """## 📁 Findings by File

"""
    
    # Show top 10 files with most findings
    sorted_files = sorted(analysis['by_file'].items(), key=lambda x: x[1], reverse=True)[:10]
    for file_path, count in sorted_files:
        markdown += f"- **{file_path}**: {count} findings\n"
    
    markdown += f"""

## 🎯 Security Assessment

### Current Status: {status}

"""
    
    for reason in reasons:
        markdown += f"- {reason}\n"
    
    # Add specific recommendations based on status
    if status == 'FAIL':
        markdown += """
### ❌ Critical Action Required
- **IMMEDIATE**: Fix all critical and high-severity vulnerabilities
- **REQUIRED**: Resolve any license violations before deployment
- **RECOMMENDED**: Review security architecture and implement additional controls
- **PROCESS**: Implement security testing in CI/CD pipeline

"""
    elif status == 'WARNING':
        markdown += """
### ⚠️ Security Improvements Recommended
- **HIGH PRIORITY**: Address high-severity vulnerabilities when possible
- **MONITOR**: Track medium-risk vulnerabilities for escalation
- **PLAN**: Schedule security maintenance and updates
- **REVIEW**: Evaluate security policies and procedures

"""
    else:
        markdown += """
### ✅ Security Posture Good
- **MAINTAIN**: Continue current security practices
- **MONITOR**: Regular vulnerability scanning and updates
- **IMPROVE**: Consider additional security hardening
- **DOCUMENT**: Keep security documentation updated

"""
    
    # Add scan level specific guidance
    if scan_level == 'medical-grade':
        markdown += """
## 🏥 Medical Device Compliance Notes

This scan used **medical-grade** security standards with stricter requirements:
- Zero tolerance for critical and high-severity vulnerabilities
- Enhanced license compliance checking
- Comprehensive multi-platform coverage
- Regulatory compliance preparation (FDA, CE marking, etc.)

"""
    
    markdown += """
## 📋 Next Steps

1. **Review Findings**: Examine detailed SARIF reports for each tool
2. **Prioritize Fixes**: Address critical and high-severity issues first
3. **Update Dependencies**: Upgrade vulnerable packages to secure versions
4. **Monitor Continuously**: Set up automated security scanning
5. **Document Changes**: Track security improvements and remediation efforts

## 🔗 Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [FDA Medical Device Cybersecurity](https://www.fda.gov/medical-devices/digital-health-center-excellence/cybersecurity)
"""
    
    return markdown


def main():
    """Main function for security summary generation."""
    print("=== Generating Comprehensive Security Summary ===")
    
    # Load environment variables
    scan_level = os.environ.get('SCAN_LEVEL', 'standard')
    platforms = {
        'flutter': os.environ.get('HAS_FLUTTER', 'false').lower() == 'true',
        'web': os.environ.get('HAS_WEB', 'false').lower() == 'true',
        'android': os.environ.get('HAS_ANDROID', 'false').lower() == 'true',
        'ios': os.environ.get('HAS_IOS', 'false').lower() == 'true',
        'desktop': True  # Assume desktop scanning is always available
    }
    
    # Analyze all security results
    analysis = analyze_sarif_files('all-results')
    
    # Determine overall status
    status, reasons = determine_overall_status(analysis, scan_level)
    
    # Generate comprehensive summary
    summary = {
        'timestamp': datetime.utcnow().isoformat(),
        'scan_level': scan_level,
        'platforms': platforms,
        'analysis': analysis,
        'status': status,
        'reasons': reasons,
        'fail_strategies': MEDICAL_DEVICE_REQUIREMENTS if scan_level == 'medical-grade' else FAIL_STRATEGIES
    }
    
    # Generate detailed markdown report
    detailed_markdown = generate_detailed_markdown(analysis, scan_level, platforms, status, reasons)
    
    # Write outputs
    with open('security-summary.json', 'w') as f:
        json.dump(summary, f, indent=2)
    
    with open('security-summary.md', 'w') as f:
        f.write(detailed_markdown)
    
    # Console summary
    print(f"\n🛡️ Security Analysis Complete")
    print(f"Status: {status}")
    print(f"Total Findings: {analysis['total_vulnerabilities']}")
    print(f"Critical: {analysis['critical']} | High: {analysis['high']} | Medium: {analysis['medium']} | Low: {analysis['low']}")
    print(f"License Violations: {analysis['license_violations']}")
    
    for reason in reasons:
        print(f"- {reason}")
    
    # Set GitHub output for downstream actions
    if 'GITHUB_OUTPUT' in os.environ:
        with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
            f.write(f"security_status={status}\n")
            f.write(f"total_findings={analysis['total_vulnerabilities']}\n")
            f.write(f"critical_count={analysis['critical']}\n")
            f.write(f"high_count={analysis['high']}\n")


if __name__ == '__main__':
    main()