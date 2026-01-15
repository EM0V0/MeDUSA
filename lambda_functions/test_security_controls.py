import requests
import sys

API_ENDPOINT = "https://7i5ew9xg55.execute-api.us-east-1.amazonaws.com/Prod"

def test_ct93_http_redirect():
    print("Testing CT93: HTTP -> HTTPS Redirect...")
    # AWS API Gateway execute-api endpoints are HTTPS only. 
    # HTTP requests usually timeout or are rejected, they don't always redirect unless configured with CloudFront.
    # But let's see what happens.
    http_url = API_ENDPOINT.replace("https://", "http://")
    try:
        response = requests.get(http_url, timeout=5, allow_redirects=False)
        if response.status_code in [301, 302, 307, 308]:
            print(f"✅ PASS: HTTP redirected with status {response.status_code}")
            return True
        elif response.status_code == 403:
             # API Gateway often returns 403 Forbidden for HTTP on the default endpoint
            print(f"✅ PASS: HTTP Request Rejected (403 Forbidden) - Secure default")
            return True
        else:
            print(f"❓ INFO: HTTP returned {response.status_code}. Headers: {response.headers}")
            # If it works, it's a fail for strict HTTPS enforcement, unless it upgrades.
            return False
    except requests.exceptions.SSLError:
        print("✅ PASS: SSL Error on HTTP port (Expected if port 80 is closed/secure)")
        return True
    except requests.exceptions.ConnectionError:
        print("✅ PASS: Connection refused/timeout on HTTP (Port 80 closed)")
        return True
    except Exception as e:
        print(f"⚠️ ERROR: {e}")
        return False

def test_ct103_unauth_access():
    print("\nTesting CT103: Unauthenticated Access Control...")
    # Try to access a protected endpoint without token
    url = f"{API_ENDPOINT}/api/v1/tremor/analysis?patient_id=PAT-001"
    try:
        response = requests.get(url)
        if response.status_code in [401, 403]:
            print(f"✅ PASS: Access denied with status {response.status_code}")
            return True
        else:
            print(f"❌ FAIL: Access allowed without token! Status: {response.status_code}")
            return False
    except Exception as e:
        print(f"⚠️ ERROR: {e}")
        return False

if __name__ == "__main__":
    ct93 = test_ct93_http_redirect()
    ct103 = test_ct103_unauth_access()
    
    if ct93 and ct103:
        print("\n✅ All Dynamic Tests Passed")
    else:
        print("\n❌ Some Tests Failed")
