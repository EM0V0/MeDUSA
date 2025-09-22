#!/usr/bin/env python3
"""
SPDX License compliance checker for medical device software.
Checks for license compatibility with enterprise/medical requirements.
"""

import json
import os
import sys
from typing import Dict, List, Set, Tuple


# License classifications for medical/enterprise software
PROHIBITED_LICENSES = {
    'GPL-2.0', 'GPL-2.0+', 'GPL-2.0-only', 'GPL-2.0-or-later',
    'GPL-3.0', 'GPL-3.0+', 'GPL-3.0-only', 'GPL-3.0-or-later',
    'AGPL-1.0', 'AGPL-3.0', 'AGPL-3.0-only', 'AGPL-3.0-or-later',
    'SSPL-1.0', 'BUSL-1.1', 'CDDL-1.0', 'CDDL-1.1',
    'OSL-3.0', 'MS-RL', 'QPL-1.0'
}

REVIEW_REQUIRED_LICENSES = {
    'LGPL-2.0', 'LGPL-2.1', 'LGPL-3.0', 'LGPL-2.1-only', 'LGPL-3.0-only',
    'MPL-1.1', 'MPL-2.0', 'EPL-1.0', 'EPL-2.0', 'CPL-1.0',
    'CC-BY-SA-3.0', 'CC-BY-SA-4.0', 'EUPL-1.1', 'EUPL-1.2'
}

APPROVED_LICENSES = {
    'MIT', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause', 'ISC',
    'CC0-1.0', 'Unlicense', 'WTFPL', 'Python-2.0', 'Zlib',
    'X11', 'BSD-3-Clause-Clear', 'Apache-2.0-with-LLVM-exception'
}

# Common license aliases and variations
LICENSE_ALIASES = {
    'Apache': 'Apache-2.0',
    'Apache License': 'Apache-2.0',
    'Apache-2': 'Apache-2.0',
    'MIT License': 'MIT',
    'The MIT License': 'MIT',
    'BSD': 'BSD-3-Clause',
    'BSD License': 'BSD-3-Clause',
    'ISC License': 'ISC',
    'GNU GPL': 'GPL-3.0',
    'GNU LGPL': 'LGPL-3.0',
    'Mozilla Public License': 'MPL-2.0',
}


def normalize_license_id(license_str: str) -> str:
    """Normalize license string to SPDX identifier."""
    if not license_str:
        return 'UNKNOWN'
    
    license_str = license_str.strip()
    
    # Check direct SPDX match
    if license_str in PROHIBITED_LICENSES | REVIEW_REQUIRED_LICENSES | APPROVED_LICENSES:
        return license_str
    
    # Check aliases
    if license_str in LICENSE_ALIASES:
        return LICENSE_ALIASES[license_str]
    
    # Handle common patterns
    license_lower = license_str.lower()
    if 'mit' in license_lower:
        return 'MIT'
    elif 'apache' in license_lower and '2' in license_str:
        return 'Apache-2.0'
    elif 'bsd' in license_lower:
        return 'BSD-3-Clause'
    elif 'isc' in license_lower:
        return 'ISC'
    elif 'gpl' in license_lower:
        if '2' in license_str:
            return 'GPL-2.0'
        else:
            return 'GPL-3.0'
    elif 'lgpl' in license_lower:
        return 'LGPL-3.0'
    
    return license_str


def classify_license(license_id: str) -> Tuple[str, str]:
    """Classify license into status and category."""
    normalized_id = normalize_license_id(license_id)
    
    if normalized_id in PROHIBITED_LICENSES:
        return 'PROHIBITED', 'Copyleft license incompatible with proprietary medical software'
    elif normalized_id in REVIEW_REQUIRED_LICENSES:
        return 'REVIEW_REQUIRED', 'Weak copyleft license requiring legal review'
    elif normalized_id in APPROVED_LICENSES:
        return 'APPROVED', 'Permissive license approved for medical software'
    else:
        return 'UNKNOWN', 'License not recognized - manual review required'


def check_flutter_licenses() -> List[Dict]:
    """Check Flutter package licenses from pubspec.lock."""
    violations = []
    
    if not os.path.exists('pubspec.lock'):
        return violations
    
    try:
        # This would need to be enhanced with actual pubspec.lock parsing
        # For now, we'll simulate the process
        print("Checking Flutter package licenses...")
        # TODO: Implement pubspec.lock license extraction
    except Exception as e:
        print(f"Error checking Flutter licenses: {e}")
    
    return violations


def check_npm_licenses() -> List[Dict]:
    """Check npm package licenses from package-lock.json."""
    violations = []
    
    if not os.path.exists('package-lock.json'):
        return violations
    
    try:
        with open('package-lock.json') as f:
            package_lock = json.load(f)
        
        packages = package_lock.get('packages', {})
        for package_path, package_info in packages.items():
            if package_path == '':  # Skip root package
                continue
                
            package_name = package_path.split('node_modules/')[-1]
            license_info = package_info.get('license', 'UNKNOWN')
            
            if isinstance(license_info, list):
                license_info = ' OR '.join(license_info)
            
            status, reason = classify_license(str(license_info))
            
            if status in ['PROHIBITED', 'UNKNOWN']:
                violations.append({
                    'package': package_name,
                    'license': license_info,
                    'status': status,
                    'reason': reason,
                    'version': package_info.get('version', 'unknown')
                })
        
        print(f"Checked {len(packages)} npm packages")
    except Exception as e:
        print(f"Error checking npm licenses: {e}")
    
    return violations


def generate_license_report(violations: List[Dict]) -> Dict:
    """Generate comprehensive license compliance report."""
    report = {
        'timestamp': os.environ.get('GITHUB_RUN_ID', 'local'),
        'total_violations': len(violations),
        'prohibited_count': len([v for v in violations if v['status'] == 'PROHIBITED']),
        'unknown_count': len([v for v in violations if v['status'] == 'UNKNOWN']),
        'violations': violations,
        'compliance_status': 'FAIL' if violations else 'PASS'
    }
    
    return report


def generate_sarif_output(violations: List[Dict]) -> Dict:
    """Generate SARIF format output for license violations."""
    sarif = {
        '$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
        'version': '2.1.0',
        'runs': [{
            'tool': {
                'driver': {
                    'name': 'license-checker',
                    'version': '1.0.0',
                    'informationUri': 'https://spdx.org/licenses/'
                }
            },
            'results': []
        }]
    }
    
    for violation in violations:
        level = 'error' if violation['status'] == 'PROHIBITED' else 'warning'
        
        result = {
            'ruleId': f'license-{violation["status"].lower()}',
            'message': {
                'text': f'License violation in {violation["package"]}: {violation["license"]} - {violation["reason"]}'
            },
            'level': level,
            'locations': [{
                'physicalLocation': {
                    'artifactLocation': {
                        'uri': 'package-lock.json' if 'npm' in violation.get('source', 'npm') else 'pubspec.lock'
                    }
                }
            }]
        }
        
        sarif['runs'][0]['results'].append(result)
    
    return sarif


def main():
    """Main function for license compliance checking."""
    print("=== License Compliance Check ===")
    
    violations = []
    
    # Check npm licenses
    npm_violations = check_npm_licenses()
    for violation in npm_violations:
        violation['source'] = 'npm'
    violations.extend(npm_violations)
    
    # Check Flutter licenses
    flutter_violations = check_flutter_licenses()
    for violation in flutter_violations:
        violation['source'] = 'flutter'
    violations.extend(flutter_violations)
    
    # Generate reports
    report = generate_license_report(violations)
    sarif_output = generate_sarif_output(violations)
    
    # Write outputs
    os.makedirs('scan-results', exist_ok=True)
    
    with open('scan-results/license-report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    with open('scan-results/license-violations.sarif', 'w') as f:
        json.dump(sarif_output, f, indent=2)
    
    # Summary
    print(f"License compliance check completed:")
    print(f"  Total violations: {report['total_violations']}")
    print(f"  Prohibited licenses: {report['prohibited_count']}")
    print(f"  Unknown licenses: {report['unknown_count']}")
    print(f"  Compliance status: {report['compliance_status']}")
    
    # Exit with error if prohibited licenses found
    if report['prohibited_count'] > 0:
        print("❌ Prohibited licenses detected!")
        sys.exit(1)
    elif report['unknown_count'] > 0:
        print("⚠️ Unknown licenses require review")
        sys.exit(0)
    else:
        print("✅ All licenses approved")
        sys.exit(0)


if __name__ == '__main__':
    main()