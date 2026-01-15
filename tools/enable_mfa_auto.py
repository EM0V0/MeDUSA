import requests
import json
import sys
import time
import pyotp

# API Base URL
BASE_URL = "https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1"

def login(email, password):
    print(f"Logging in as {email}...")
    url = f"{BASE_URL}/auth/login"
    payload = {"email": email, "password": password}
    
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.HTTPError as e:
        print(f"Login failed: {e.response.text}")
        return None
    except Exception as e:
        print(f"An error occurred: {e}")
        return None

def setup_mfa(token):
    print("Initiating MFA Setup...")
    url = f"{BASE_URL}/auth/mfa/setup"
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.post(url, headers=headers)
        response.raise_for_status()
        data = response.json()
        return data.get("secret"), data.get("qrCodeUrl")
    except requests.exceptions.HTTPError as e:
        print(f"MFA Setup failed: {e.response.text}")
        return None, None

def verify_mfa(token, code):
    print(f"Verifying code {code}...")
    url = f"{BASE_URL}/auth/mfa/verify"
    headers = {"Authorization": f"Bearer {token}"}
    payload = {"code": code}
    
    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        print("✅ MFA Verified and Enabled successfully!")
        return True
    except requests.exceptions.HTTPError as e:
        print(f"❌ Verification failed: {e.response.text}")
        return False

def enable_for_user(email, password):
    print(f"\n{'='*60}")
    print(f"Processing User: {email}")
    print(f"{'='*60}")
    
    # 1. Login
    login_data = login(email, password)
    if not login_data:
        return

    if login_data.get("mfaRequired"):
        print(f"⚠️  MFA is ALREADY enabled for {email}!")
        return

    access_token = login_data.get("accessJwt")
    if not access_token:
        print("Error: No access token received.")
        return

    # 2. Setup MFA
    secret, qr_url = setup_mfa(access_token)
    if not secret:
        return
    
    print(f"Secret generated: {secret}")
    
    # 3. Generate Code and Verify
    totp = pyotp.TOTP(secret)
    code = totp.now()
    print(f"Generated TOTP code: {code}")
    
    if verify_mfa(access_token, code):
        print(f"\nSUCCESS! MFA is now enabled for {email}")
        print(f"Please add this secret to your Authenticator App manually:")
        print(f"Secret: {secret}")

if __name__ == "__main__":
    users = [
        ("zsun54@jh.edu", "Testhnp123!"),
        ("andysun12@outlook.com", "Testhnp123!")
    ]
    
    for email, password in users:
        enable_for_user(email, password)
