#!/usr/bin/env python3
"""
Enhanced Flutter security auditing with multi-lockfile support.
Supports package-lock.json, yarn.lock, and pnpm-lock.yaml scanning.
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional


def check_flutter_dependencies() -> List[Dict]:
    """Audit Flutter dependencies from pubspec.lock."""
    vulnerabilities = []
    
    if not os.path.exists('pubspec.lock'):
        print("No pubspec.lock found, skipping Flutter audit")
        return vulnerabilities
    
    try:
        # Use flutter pub deps to analyze dependencies
        result = subprocess.run(
            ['flutter', 'pub', 'deps', '--json'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            deps_data = json.loads(result.stdout)
            print(f"Analyzed Flutter dependencies: {len(deps_data.get('packages', []))} packages")
            
            # Check for known vulnerable packages (this would be enhanced with real vulnerability DB)
            for package in deps_data.get('packages', []):
                # Placeholder for actual vulnerability checking
                if package.get('name') in ['vulnerable_package_example']:
                    vulnerabilities.append({
                        'package': package['name'],
                        'version': package.get('version', 'unknown'),
                        'severity': 'high',
                        'description': 'Example vulnerable package'
                    })
        
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Error auditing Flutter dependencies: {e}")
    
    return vulnerabilities


def check_npm_lockfile(lockfile_path: str) -> List[Dict]:
    """Check npm package-lock.json for vulnerabilities."""
    vulnerabilities = []
    
    if not os.path.exists(lockfile_path):
        return vulnerabilities
    
    try:
        # Run npm audit on the lockfile
        result = subprocess.run(
            ['npm', 'audit', '--json', '--package-lock-only'],
            cwd=os.path.dirname(lockfile_path) or '.',
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.stdout:
            audit_data = json.loads(result.stdout)
            for vuln_id, vuln in audit_data.get('vulnerabilities', {}).items():
                vulnerabilities.append({
                    'source': 'npm',
                    'package': vuln.get('name', vuln_id),
                    'version': vuln.get('range', 'unknown'),
                    'severity': vuln.get('severity', 'unknown'),
                    'description': vuln.get('title', 'No description'),
                    'cwe': vuln.get('cwe', []),
                    'url': vuln.get('url', '')
                })
        
        print(f"npm audit found {len(vulnerabilities)} vulnerabilities in {lockfile_path}")
        
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Error checking npm lockfile {lockfile_path}: {e}")
    
    return vulnerabilities


def check_yarn_lockfile(lockfile_path: str) -> List[Dict]:
    """Check yarn.lock for vulnerabilities using yarn audit."""
    vulnerabilities = []
    
    if not os.path.exists(lockfile_path):
        return vulnerabilities
    
    try:
        # Run yarn audit
        result = subprocess.run(
            ['yarn', 'audit', '--json'],
            cwd=os.path.dirname(lockfile_path) or '.',
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.stdout:
            # Yarn audit outputs multiple JSON objects, one per line
            for line in result.stdout.strip().split('\n'):
                if line:
                    try:
                        audit_data = json.loads(line)
                        if audit_data.get('type') == 'auditAdvisory':
                            data = audit_data.get('data', {})
                            advisory = data.get('advisory', {})
                            
                            vulnerabilities.append({
                                'source': 'yarn',
                                'package': advisory.get('module_name', 'unknown'),
                                'version': advisory.get('vulnerable_versions', 'unknown'),
                                'severity': advisory.get('severity', 'unknown'),
                                'description': advisory.get('title', 'No description'),
                                'cwe': advisory.get('cwe', []),
                                'url': advisory.get('url', '')
                            })
                    except json.JSONDecodeError:
                        continue
        
        print(f"yarn audit found {len(vulnerabilities)} vulnerabilities in {lockfile_path}")
        
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as e:
        print(f"Error checking yarn lockfile {lockfile_path}: {e}")
    
    return vulnerabilities


def check_pnpm_lockfile(lockfile_path: str) -> List[Dict]:
    """Check pnpm-lock.yaml for vulnerabilities using pnpm audit."""
    vulnerabilities = []
    
    if not os.path.exists(lockfile_path):
        return vulnerabilities
    
    try:
        # Run pnpm audit
        result = subprocess.run(
            ['pnpm', 'audit', '--json'],
            cwd=os.path.dirname(lockfile_path) or '.',
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.stdout:
            audit_data = json.loads(result.stdout)
            advisories = audit_data.get('advisories', {})
            
            for advisory_id, advisory in advisories.items():
                vulnerabilities.append({
                    'source': 'pnpm',
                    'package': advisory.get('module_name', 'unknown'),
                    'version': advisory.get('vulnerable_versions', 'unknown'),
                    'severity': advisory.get('severity', 'unknown'),
                    'description': advisory.get('title', 'No description'),
                    'cwe': advisory.get('cwe', []),
                    'url': advisory.get('url', '')
                })
        
        print(f"pnpm audit found {len(vulnerabilities)} vulnerabilities in {lockfile_path}")
        
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Error checking pnpm lockfile {lockfile_path}: {e}")
    
    return vulnerabilities


def find_lockfiles() -> List[tuple]:
    """Find all lockfiles in the project."""
    lockfiles = []
    
    # Check for different types of lockfiles
    if os.path.exists('package-lock.json'):
        lockfiles.append(('npm', 'package-lock.json'))
    if os.path.exists('yarn.lock'):
        lockfiles.append(('yarn', 'yarn.lock'))
    if os.path.exists('pnpm-lock.yaml'):
        lockfiles.append(('pnpm', 'pnpm-lock.yaml'))
    
    # Also check in subdirectories (common in monorepos)
    for root, dirs, files in os.walk('.'):
        if root == '.':  # Skip root as we already checked
            continue
        for file in files:
            if file in ['package-lock.json', 'yarn.lock', 'pnpm-lock.yaml']:
                lockfile_type = {'package-lock.json': 'npm', 'yarn.lock': 'yarn', 'pnpm-lock.yaml': 'pnpm'}[file]
                lockfiles.append((lockfile_type, os.path.join(root, file)))
    
    return lockfiles


def convert_to_sarif(vulnerabilities: List[Dict]) -> Dict:
    """Convert vulnerability list to SARIF format."""
    sarif = {
        '$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
        'version': '2.1.0',
        'runs': [{
            'tool': {
                'driver': {
                    'name': 'flutter-audit',
                    'version': '1.0.0',
                    'informationUri': 'https://dart.dev/tools/pub/security-advisories'
                }
            },
            'results': []
        }]
    }
    
    severity_map = {
        'critical': 'error',
        'high': 'error',
        'moderate': 'warning',
        'medium': 'warning',
        'low': 'note',
        'info': 'note'
    }
    
    for vuln in vulnerabilities:
        level = severity_map.get(vuln.get('severity', 'medium'), 'warning')
        
        result = {
            'ruleId': f'{vuln.get("source", "flutter")}-{vuln.get("package", "unknown")}',
            'message': {
                'text': f'{vuln.get("source", "Flutter")} vulnerability: {vuln.get("description", "Unknown")} in {vuln.get("package", "unknown")}'
            },
            'level': level,
            'locations': [{
                'physicalLocation': {
                    'artifactLocation': {
                        'uri': {
                            'npm': 'package-lock.json',
                            'yarn': 'yarn.lock', 
                            'pnpm': 'pnpm-lock.yaml',
                            'flutter': 'pubspec.lock'
                        }.get(vuln.get('source', 'flutter'), 'pubspec.lock')
                    }
                }
            }]
        }
        
        if vuln.get('url'):
            result['helpUri'] = vuln['url']
        
        sarif['runs'][0]['results'].append(result)
    
    return sarif


def main():
    """Main function for enhanced Flutter auditing."""
    print("=== Enhanced Flutter Security Audit ===")
    
    all_vulnerabilities = []
    
    # Check Flutter dependencies
    flutter_vulns = check_flutter_dependencies()
    all_vulnerabilities.extend(flutter_vulns)
    
    # Check all lockfiles
    lockfiles = find_lockfiles()
    print(f"Found {len(lockfiles)} lockfile(s): {[lf[1] for lf in lockfiles]}")
    
    for lockfile_type, lockfile_path in lockfiles:
        if lockfile_type == 'npm':
            vulns = check_npm_lockfile(lockfile_path)
        elif lockfile_type == 'yarn':
            vulns = check_yarn_lockfile(lockfile_path)
        elif lockfile_type == 'pnpm':
            vulns = check_pnpm_lockfile(lockfile_path)
        else:
            continue
        
        all_vulnerabilities.extend(vulns)
    
    # Generate outputs
    os.makedirs('scan-results', exist_ok=True)
    
    sarif_output = convert_to_sarif(all_vulnerabilities)
    with open('scan-results/flutter-audit.sarif', 'w') as f:
        json.dump(sarif_output, f, indent=2)
    
    # Summary
    print(f"Flutter audit completed:")
    print(f"  Total vulnerabilities: {len(all_vulnerabilities)}")
    
    severity_counts = {}
    for vuln in all_vulnerabilities:
        severity = vuln.get('severity', 'unknown')
        severity_counts[severity] = severity_counts.get(severity, 0) + 1
    
    for severity, count in severity_counts.items():
        print(f"  {severity.capitalize()}: {count}")
    
    if all_vulnerabilities:
        print("⚠️ Vulnerabilities found - review required")
    else:
        print("✅ No vulnerabilities detected")


if __name__ == '__main__':
    main()