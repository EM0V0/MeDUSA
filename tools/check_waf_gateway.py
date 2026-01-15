import requests
import json

# 使用你刚才确认的 API 端点
BASE_URL = "https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod"

def print_result(test_name, response, expected_status=[403, 406]):
    status = response.status_code
    is_blocked = status in expected_status
    icon = "✅" if is_blocked else "❌"
    print(f"{icon} {test_name}")
    print(f"   Status: {status}")
    print(f"   Response: {response.text[:100]}...")
    if not is_blocked:
        print(f"   ⚠️ Warning: Request was NOT blocked as expected (Expected {expected_status})")
    print("-" * 40)

print(f"🛡️ Testing Security Controls for: {BASE_URL}\n")

# 1. Test SQL Injection (WAF should block)
print("1. Testing SQL Injection Protection...")
sqli_payload = {"email": "' OR '1'='1", "password": "password"}
try:
    res = requests.post(f"{BASE_URL}/auth/login", json=sqli_payload)
    print_result("SQL Injection Attempt", res)
except Exception as e:
    print(f"Error: {e}")

# 2. Test XSS Injection (WAF should block)
print("\n2. Testing XSS Protection...")
xss_payload = {"email": "<script>alert(1)</script>", "password": "password"}
try:
    res = requests.post(f"{BASE_URL}/auth/login", json=xss_payload)
    print_result("XSS Attempt", res)
except Exception as e:
    print(f"Error: {e}")

# 3. Test Bad User Agent (Bot Protection)
print("\n3. Testing Bot Protection (Bad User-Agent)...")
headers = {"User-Agent": "EvilBot/1.0"}
try:
    res = requests.get(f"{BASE_URL}/auth/health", headers=headers)
    # Note: Standard AWS WAF rules might not block this by default unless configured
    print_result("Bad User-Agent", res, expected_status=[403])
except Exception as e:
    print(f"Error: {e}")

# 4. Test API Gateway Throttling/Invalid Method
print("\n4. Testing API Gateway Method Validation...")
try:
    # Sending PUT to an endpoint that only accepts POST
    res = requests.put(f"{BASE_URL}/auth/login", json={})
    print_result("Invalid HTTP Method", res, expected_status=[403, 404, 405])
except Exception as e:
    print(f"Error: {e}")
