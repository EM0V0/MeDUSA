import zipfile
import os

zip_path = r"d:\25fall\Capstone\ble\MeDUSA\meddevice_android_only.zip"

print(f"Inspecting: {zip_path}")
try:
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        # List first 10 files to verify structure
        for file in zip_ref.namelist()[:10]:
            print(file)
            
        # Check for specific required file
        required = "app/src/main/AndroidManifest.xml"
        if required in zip_ref.namelist():
            print(f"\nSUCCESS: Found {required}")
        else:
            print(f"\nFAILURE: Could not find {required}")
            
except Exception as e:
    print(f"Error: {e}")
