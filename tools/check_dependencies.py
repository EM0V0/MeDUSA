import csv
import requests
import json
import sys
from packaging import version

def get_latest_pypi_version(package_name):
    try:
        response = requests.get(f"https://pypi.org/pypi/{package_name}/json", timeout=5)
        if response.status_code == 200:
            data = response.json()
            return data["info"]["version"]
    except Exception:
        pass
    return None

def get_latest_pub_version(package_name):
    try:
        response = requests.get(f"https://pub.dev/api/packages/{package_name}", timeout=5)
        if response.status_code == 200:
            data = response.json()
            return data["latest"]["version"]
    except Exception:
        pass
    return None

def check_dependencies(csv_path):
    print(f"{'Package':<30} {'Current':<15} {'Latest':<15} {'Status':<10} {'Type':<10}")
    print("-" * 85)

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row['Component Name']
            current_ver = row['Version']
            manager = row['Package Manager']
            
            # Skip version ranges for now or handle them simply
            if ">=" in current_ver:
                current_ver_clean = current_ver.replace(">=", "").strip()
            else:
                current_ver_clean = current_ver

            latest_ver = None
            if manager == 'PyPI':
                latest_ver = get_latest_pypi_version(name)
            elif manager == 'Pub':
                latest_ver = get_latest_pub_version(name)
            
            status = "Unknown"
            if latest_ver:
                try:
                    if version.parse(current_ver_clean) < version.parse(latest_ver):
                        status = "Outdated"
                    else:
                        status = "Current"
                except:
                    status = "Error"
            
            print(f"{name:<30} {current_ver:<15} {str(latest_ver):<15} {status:<10} {manager:<10}")

if __name__ == "__main__":
    check_dependencies(r"d:\25fall\Capstone\ble\MeDUSA\SBOM.csv")
