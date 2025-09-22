#!/usr/bin/env python3
"""
Desktop platform dependency scanner for Windows, macOS, and Linux.
Scans system dependencies and generates vulnerability reports.
"""

import json
import os
import platform
import subprocess
import sys
from typing import Dict, List, Optional


def scan_windows_dependencies() -> List[Dict]:
    """Scan Windows dependencies using winget and chocolatey."""
    dependencies = []
    
    print("Scanning Windows dependencies...")
    
    # Try winget first
    try:
        result = subprocess.run(
            ['winget', 'list', '--accept-source-agreements'], 
            capture_output=True, 
            text=True, 
            timeout=60
        )
        
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')[2:]  # Skip header
            for line in lines:
                parts = line.split()
                if len(parts) >= 3:
                    dependencies.append({
                        'name': parts[0],
                        'version': parts[1] if len(parts) > 1 else 'unknown',
                        'source': 'winget',
                        'platform': 'windows'
                    })
        
        print(f"Found {len(dependencies)} winget packages")
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"winget scan failed: {e}")
    
    # Try chocolatey
    try:
        result = subprocess.run(
            ['choco', 'list', '--local-only'], 
            capture_output=True, 
            text=True, 
            timeout=60
        )
        
        if result.returncode == 0:
            choco_count = 0
            for line in result.stdout.strip().split('\n'):
                if ' ' in line and not line.startswith('Chocolatey'):
                    parts = line.split(' ')
                    if len(parts) >= 2:
                        dependencies.append({
                            'name': parts[0],
                            'version': parts[1],
                            'source': 'chocolatey',
                            'platform': 'windows'
                        })
                        choco_count += 1
        
        print(f"Found {choco_count} chocolatey packages")
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"chocolatey scan failed: {e}")
    
    return dependencies


def scan_macos_dependencies() -> List[Dict]:
    """Scan macOS dependencies using homebrew."""
    dependencies = []
    
    print("Scanning macOS dependencies...")
    
    try:
        # Get homebrew packages
        result = subprocess.run(
            ['brew', 'list', '--json=v2'], 
            capture_output=True, 
            text=True, 
            timeout=60
        )
        
        if result.returncode == 0:
            brew_data = json.loads(result.stdout)
            
            for formula in brew_data.get('formulae', []):
                dependencies.append({
                    'name': formula.get('name', 'unknown'),
                    'version': formula.get('installed', [{}])[0].get('version', 'unknown'),
                    'source': 'homebrew',
                    'platform': 'macos'
                })
            
            for cask in brew_data.get('casks', []):
                dependencies.append({
                    'name': cask.get('name', 'unknown'),
                    'version': cask.get('installed', 'unknown'),
                    'source': 'homebrew-cask',
                    'platform': 'macos'
                })
        
        print(f"Found {len(dependencies)} homebrew packages")
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError) as e:
        print(f"homebrew scan failed: {e}")
    
    return dependencies


def scan_linux_dependencies() -> List[Dict]:
    """Scan Linux dependencies using various package managers."""
    dependencies = []
    
    print("Scanning Linux dependencies...")
    
    # Try dpkg (Debian/Ubuntu)
    try:
        result = subprocess.run(
            ['dpkg', '-l'], 
            capture_output=True, 
            text=True, 
            timeout=60
        )
        
        if result.returncode == 0:
            dpkg_count = 0
            for line in result.stdout.strip().split('\n'):
                if line.startswith('ii'):
                    parts = line.split()
                    if len(parts) >= 3:
                        dependencies.append({
                            'name': parts[1],
                            'version': parts[2],
                            'source': 'dpkg',
                            'platform': 'linux'
                        })
                        dpkg_count += 1
        
        print(f"Found {dpkg_count} dpkg packages")
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"dpkg scan failed: {e}")
    
    # Try rpm (RedHat/CentOS/Fedora)
    try:
        result = subprocess.run(
            ['rpm', '-qa'], 
            capture_output=True, 
            text=True, 
            timeout=60
        )
        
        if result.returncode == 0:
            rpm_count = 0
            for line in result.stdout.strip().split('\n'):
                if line:
                    # RPM format is usually name-version-release.arch
                    parts = line.rsplit('-', 2)
                    if len(parts) >= 2:
                        dependencies.append({
                            'name': parts[0],
                            'version': f"{parts[1]}-{parts[2]}" if len(parts) > 2 else parts[1],
                            'source': 'rpm',
                            'platform': 'linux'
                        })
                        rpm_count += 1
        
        print(f"Found {rpm_count} rpm packages")
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"rpm scan failed: {e}")
    
    return dependencies


def scan_with_syft(dependencies: List[Dict]) -> List[Dict]:
    """Use Syft to scan for vulnerabilities in dependencies."""
    if not dependencies:
        return []
    
    vulnerabilities = []
    
    try:
        # Create a temporary SBOM for the dependencies
        temp_sbom = {
            'bomFormat': 'CycloneDX',
            'specVersion': '1.4',
            'components': []
        }
        
        for dep in dependencies:
            temp_sbom['components'].append({
                'type': 'library',
                'name': dep['name'],
                'version': dep['version'],
                'purl': f"pkg:{dep['platform']}/{dep['name']}@{dep['version']}"
            })
        
        # Write temporary SBOM
        with open('temp-desktop-sbom.json', 'w') as f:
            json.dump(temp_sbom, f)
        
        # Scan with Syft/Trivy if available
        result = subprocess.run(
            ['trivy', 'sbom', 'temp-desktop-sbom.json', '--format', 'json'], 
            capture_output=True, 
            text=True, 
            timeout=120
        )
        
        if result.returncode == 0:
            scan_data = json.loads(result.stdout)
            results = scan_data.get('Results', [])
            
            for result_item in results:
                for vuln in result_item.get('Vulnerabilities', []):
                    vulnerabilities.append({
                        'package': vuln.get('PkgName', 'unknown'),
                        'version': vuln.get('InstalledVersion', 'unknown'),
                        'vulnerability_id': vuln.get('VulnerabilityID', 'unknown'),
                        'severity': vuln.get('Severity', 'UNKNOWN'),
                        'description': vuln.get('Description', 'No description'),
                        'source': 'desktop-scan'
                    })
        
        # Clean up
        if os.path.exists('temp-desktop-sbom.json'):
            os.remove('temp-desktop-sbom.json')
        
        print(f"Trivy found {len(vulnerabilities)} vulnerabilities")
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Trivy scan failed: {e}")
    
    return vulnerabilities


def convert_to_sarif(vulnerabilities: List[Dict]) -> Dict:
    """Convert vulnerabilities to SARIF format."""
    sarif = {
        '$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
        'version': '2.1.0',
        'runs': [{
            'tool': {
                'driver': {
                    'name': 'desktop-scanner',
                    'version': '1.0.0',
                    'informationUri': 'https://github.com/anchore/syft'
                }
            },
            'results': []
        }]
    }
    
    severity_map = {
        'CRITICAL': 'error',
        'HIGH': 'error',
        'MEDIUM': 'warning',
        'LOW': 'note',
        'UNKNOWN': 'note'
    }
    
    for vuln in vulnerabilities:
        level = severity_map.get(vuln.get('severity', 'UNKNOWN'), 'warning')
        
        result = {
            'ruleId': f'desktop-vuln-{vuln.get("vulnerability_id", "unknown")}',
            'message': {
                'text': f'Desktop dependency vulnerability: {vuln.get("description", "Unknown")} in {vuln.get("package", "unknown")}'
            },
            'level': level,
            'locations': [{
                'physicalLocation': {
                    'artifactLocation': {'uri': 'desktop-dependencies'}
                }
            }]
        }
        
        sarif['runs'][0]['results'].append(result)
    
    return sarif


def main():
    """Main function for desktop platform scanning."""
    print("=== Desktop Platform Security Scan ===")
    
    current_platform = platform.system().lower()
    print(f"Detected platform: {current_platform}")
    
    dependencies = []
    
    # Scan based on platform
    if current_platform == 'windows':
        dependencies = scan_windows_dependencies()
    elif current_platform == 'darwin':  # macOS
        dependencies = scan_macos_dependencies()
    elif current_platform == 'linux':
        dependencies = scan_linux_dependencies()
    else:
        print(f"Unsupported platform: {current_platform}")
        return
    
    print(f"Found {len(dependencies)} total dependencies")
    
    # Scan for vulnerabilities
    vulnerabilities = scan_with_syft(dependencies)
    
    # Generate outputs
    os.makedirs('scan-results', exist_ok=True)
    
    # Save dependency list
    with open('scan-results/desktop-dependencies.json', 'w') as f:
        json.dump(dependencies, f, indent=2)
    
    # Save SARIF results
    if vulnerabilities:
        sarif_output = convert_to_sarif(vulnerabilities)
        with open('scan-results/desktop-vulnerabilities.sarif', 'w') as f:
            json.dump(sarif_output, f, indent=2)
    
    # Summary
    print(f"Desktop scan completed:")
    print(f"  Platform: {current_platform}")
    print(f"  Dependencies: {len(dependencies)}")
    print(f"  Vulnerabilities: {len(vulnerabilities)}")
    
    if vulnerabilities:
        severity_counts = {}
        for vuln in vulnerabilities:
            severity = vuln.get('severity', 'UNKNOWN')
            severity_counts[severity] = severity_counts.get(severity, 0) + 1
        
        for severity, count in severity_counts.items():
            print(f"    {severity}: {count}")
        
        print("⚠️ Desktop vulnerabilities found - review required")
    else:
        print("✅ No desktop vulnerabilities detected")


if __name__ == '__main__':
    main()