#!/usr/bin/env python3
"""
Security scan results merger with deduplication support.
Merges SARIF files and npm audit results into a single SARIF report.
"""

import json
import glob
import os
import hashlib
from typing import Dict, List, Set, Tuple


def get_result_key(result: Dict) -> str:
    """Generate a unique key for deduplication based on ruleId and location."""
    rule_id = result.get('ruleId', '')
    locations = result.get('locations', [])
    
    if not locations:
        return f"{rule_id}:no-location"
    
    # Use first location for key generation
    location = locations[0]
    physical_location = location.get('physicalLocation', {})
    artifact_location = physical_location.get('artifactLocation', {})
    uri = artifact_location.get('uri', '')
    
    # Include line/column if available
    region = physical_location.get('region', {})
    line = region.get('startLine', 0)
    column = region.get('startColumn', 0)
    
    key_string = f"{rule_id}:{uri}:{line}:{column}"
    return hashlib.md5(key_string.encode()).hexdigest()


def deduplicate_results(runs: List[Dict]) -> List[Dict]:
    """Deduplicate results across runs based on ruleId and location."""
    seen_results: Set[str] = set()
    deduplicated_runs = []
    
    for run in runs:
        deduplicated_results = []
        for result in run.get('results', []):
            result_key = get_result_key(result)
            if result_key not in seen_results:
                seen_results.add(result_key)
                deduplicated_results.append(result)
        
        if deduplicated_results:
            run_copy = run.copy()
            run_copy['results'] = deduplicated_results
            deduplicated_runs.append(run_copy)
    
    return deduplicated_runs


def convert_npm_audit_to_sarif(npm_audit_file: str) -> Dict:
    """Convert npm audit results to SARIF format."""
    try:
        with open(npm_audit_file) as f:
            npm_data = json.load(f)
        
        npm_run = {
            'tool': {
                'driver': {
                    'name': 'npm-audit',
                    'version': '1.0.0',
                    'informationUri': 'https://docs.npmjs.com/cli/v8/commands/npm-audit'
                }
            },
            'results': []
        }
        
        severity_map = {
            'low': 'note',
            'moderate': 'warning', 
            'high': 'error',
            'critical': 'error'
        }
        
        for vuln_id, vuln in npm_data.get('vulnerabilities', {}).items():
            level = severity_map.get(vuln.get('severity', 'moderate'), 'warning')
            
            result = {
                'ruleId': f'npm-audit-{vuln_id}',
                'message': {
                    'text': f'npm vulnerability: {vuln.get("title", "Unknown")} in {vuln.get("name", "unknown")}'
                },
                'level': level,
                'locations': [{
                    'physicalLocation': {
                        'artifactLocation': {'uri': 'package.json'}
                    }
                }]
            }
            
            # Add additional vulnerability info if available
            if vuln.get('url'):
                result['helpUri'] = vuln['url']
            if vuln.get('range'):
                result['message']['text'] += f' (version range: {vuln["range"]})'
                
            npm_run['results'].append(result)
        
        return npm_run
    except Exception as e:
        print(f'Error processing npm audit: {e}')
        return None


def main():
    """Main function to merge all security scan results."""
    merged_sarif = {
        '$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
        'version': '2.1.0',
        'runs': []
    }
    
    total_findings = 0
    runs_to_merge = []
    
    # Process SARIF files
    sarif_files = glob.glob('scan-results/*.sarif')
    for sarif_file in sarif_files:
        try:
            with open(sarif_file) as f:
                data = json.load(f)
            
            for run in data.get('runs', []):
                results = run.get('results', [])
                if results:
                    runs_to_merge.append(run)
                    print(f'Found {len(results)} results from {os.path.basename(sarif_file)}')
        except Exception as e:
            print(f'Error processing {sarif_file}: {e}')
    
    # Process npm audit results
    npm_audit_file = 'scan-results/npm-audit.json'
    if os.path.exists(npm_audit_file):
        npm_run = convert_npm_audit_to_sarif(npm_audit_file)
        if npm_run and npm_run['results']:
            runs_to_merge.append(npm_run)
            print(f'Added {len(npm_run["results"])} npm audit results')
    
    # Deduplicate results
    if runs_to_merge:
        deduplicated_runs = deduplicate_results(runs_to_merge)
        merged_sarif['runs'] = deduplicated_runs
        
        # Count total findings after deduplication
        for run in deduplicated_runs:
            total_findings += len(run.get('results', []))
    
    # Write merged results
    with open('universal-security-results.sarif', 'w') as f:
        json.dump(merged_sarif, f, indent=2)
    
    print(f'Merge completed: {total_findings} total findings (after deduplication)')


if __name__ == '__main__':
    main()