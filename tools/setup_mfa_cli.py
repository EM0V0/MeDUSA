import requests
import json
import sys
import getpass
import time

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
        sys.exit(1)
    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)

def setup_mfa(token):
    print("\nInitiating MFA Setup...")
    url = f"{BASE_URL}/auth/mfa/setup"
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.post(url, headers=headers)
        response.raise_for_status()
        data = response.json()
        return data.get("secret"), data.get("qrCodeUrl")
    except requests.exceptions.HTTPError as e:
        print(f"MFA Setup failed: {e.response.text}")
        sys.exit(1)

def verify_mfa(token, code):
    print(f"\nVerifying code {code}...")
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

def main():
    print("=== MeDUSA MFA Setup Tool ===")
    print("This tool will enable MFA for your account so you can test the login flow in the App.\n")
    
    email = input("Enter your email: ").strip()
    password = getpass.getpass("Enter your password: ").strip()
    
    # 1. Login
    login_data = login(email, password)
    
    if login_data.get("mfaRequired"):
        print("\n⚠️  MFA is ALREADY enabled for this account!")
        print("You should already be seeing the MFA prompt in the App.")
        return

    access_token = login_data.get("accessJwt")
    if not access_token:
        print("Error: No access token received.")
        return

    # 2. Setup MFA
    secret, qr_url = setup_mfa(access_token)
    
    print("\n" + "="*50)
    print(f"SECRET KEY: {secret}")
    print("="*50)
    print("\n1. Open your Authenticator App (Google Authenticator, Authy, etc.)")
    print("2. Select 'Add Account' -> 'Enter Manual Key'")
    print(f"3. Enter Account Name: MeDUSA ({email})")
    print(f"4. Enter Key: {secret}")
    print("\n(Or if you can view the QR code URL: {qr_url})")
    
    # 3. Verify
    while True:
        code = input("\nEnter the 6-digit code from your app to verify (or 'q' to quit): ").strip()
        if code.lower() == 'q':
            break
            
        if verify_mfa(access_token, code):
            print("\n🎉 You are all set! Now try logging in via the Flutter App.")
            break

if __name__ == "__main__":
    main()
