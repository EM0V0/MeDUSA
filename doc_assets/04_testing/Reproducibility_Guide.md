# Reproduction and Verification Guide (Windows PowerShell)

**Prerequisites**: Python 3.10+ installed, AWS CLI configured (if accessing AWS resources), currently in the repository root directory.

## 1. Set Environment Variables (Local Testing)

```powershell
# Set JWT secret (Example for local testing only)
$env:JWT_SECRET = "dev-secret-key-please-change-in-production"
# Optional: Set token lifetime (seconds)
$env:JWT_EXPIRE_SECONDS = "3600"
$env:REFRESH_TTL_SECONDS = "604800"
```

## 2. Start Local Backend

To run the backend locally using the provided start script:

```powershell
cd backend/backend-py
.\start_local.ps1
```

## 3. Register Demo Device

Run the registration script to write a demo device entry to the DynamoDB table (for quick binding):

```powershell
# Return to root directory
cd ../..
python tools/register_device.py
# Output Example: Successfully registered device medusa-pi-01 to patient usr_694c4028
```

## 4. Run Diagnostic Scripts

Run the timestamp diagnostic script to collect statistics:

```powershell
python tools/check_timestamps.py
```

Output will include: Total entries, Start/End time, Min/Max/Avg intervals, gaps >1.5s, and sample timestamps.

## 5. Test API Authorization

Example: Calling a protected endpoint.

1. Obtain an `accessJwt` from the login endpoint (or read from backend test scripts).
2. Use `curl` or PowerShell `Invoke-RestMethod` to test the protected endpoint:

```powershell
$token = "<accessJwt from login>"
Invoke-RestMethod -Uri "https://<api>/api/v1/current-session" -Headers @{ Authorization = "Bearer $token" } -Method Get
```

## 6. Verify Authorizer Behavior (Manual Check)

Verify that requests without the Bearer token are rejected with 401 Unauthorized.
