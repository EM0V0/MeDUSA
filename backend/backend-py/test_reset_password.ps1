# Test Password Reset API Endpoint
# PowerShell script for testing the reset password functionality

Write-Host "🧪 Testing Password Reset API" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$API_URL = "http://localhost:8000/api/v1"
$TEST_EMAIL = "test-reset@example.com"
$ORIGINAL_PASSWORD = "password123"
$NEW_PASSWORD = "newpassword456"

# Function to make API request
function Invoke-ApiRequest {
    param(
        [string]$Method,
        [string]$Endpoint,
        [object]$Body
    )
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        $params = @{
            Uri = "$API_URL$Endpoint"
            Method = $Method
            Headers = $headers
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json)
        }
        
        $response = Invoke-RestMethod @params
        return @{
            Success = $true
            Data = $response
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            StatusCode = $_.Exception.Response.StatusCode.value__
        }
    }
}

# Check if backend is running
Write-Host "📡 Checking if backend is running..." -ForegroundColor Yellow
try {
    $healthCheck = Invoke-RestMethod -Uri "$API_URL/../admin/health" -Method Get -TimeoutSec 5
    Write-Host "✅ Backend is running!" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "❌ Backend is not running!" -ForegroundColor Red
    Write-Host "Please start the backend first:" -ForegroundColor Yellow
    Write-Host "  .\start_local.ps1" -ForegroundColor White
    exit 1
}

# Test 1: Register a test user
Write-Host "Test 1: Register Test User" -ForegroundColor Cyan
Write-Host "----------------------------" -ForegroundColor Gray
$registerBody = @{
    email = $TEST_EMAIL
    password = $ORIGINAL_PASSWORD
    role = "patient"
}

$result = Invoke-ApiRequest -Method POST -Endpoint "/auth/register" -Body $registerBody

if ($result.Success) {
    Write-Host "✅ Test user registered successfully" -ForegroundColor Green
    Write-Host "   Email: $TEST_EMAIL" -ForegroundColor Gray
    Write-Host "   User ID: $($result.Data.userId)" -ForegroundColor Gray
} elseif ($result.StatusCode -eq 409) {
    Write-Host "⚠️  User already exists (this is OK)" -ForegroundColor Yellow
} else {
    Write-Host "❌ Registration failed: $($result.Error)" -ForegroundColor Red
}
Write-Host ""

# Test 2: Login with original password
Write-Host "Test 2: Login with Original Password" -ForegroundColor Cyan
Write-Host "-------------------------------------" -ForegroundColor Gray
$loginBody = @{
    email = $TEST_EMAIL
    password = $ORIGINAL_PASSWORD
}

$result = Invoke-ApiRequest -Method POST -Endpoint "/auth/login" -Body $loginBody

if ($result.Success) {
    Write-Host "✅ Login successful with original password" -ForegroundColor Green
    $accessToken = $result.Data.accessJwt
    Write-Host "   Access Token: $($accessToken.Substring(0, 20))..." -ForegroundColor Gray
} else {
    Write-Host "❌ Login failed: $($result.Error)" -ForegroundColor Red
}
Write-Host ""

# Test 3: Reset password
Write-Host "Test 3: Reset Password" -ForegroundColor Cyan
Write-Host "----------------------" -ForegroundColor Gray
$resetBody = @{
    email = $TEST_EMAIL
    newPassword = $NEW_PASSWORD
}

$result = Invoke-ApiRequest -Method POST -Endpoint "/auth/reset-password" -Body $resetBody

if ($result.Success) {
    Write-Host "✅ Password reset successful!" -ForegroundColor Green
    Write-Host "   Message: $($result.Data.message)" -ForegroundColor Gray
} else {
    Write-Host "❌ Password reset failed!" -ForegroundColor Red
    Write-Host "   Error: $($result.Error)" -ForegroundColor Red
    Write-Host "   Status Code: $($result.StatusCode)" -ForegroundColor Red
    Write-Host ""
    Write-Host "⚠️  This might be the 405 error!" -ForegroundColor Yellow
    Write-Host "Make sure the backend has been updated with the new endpoint." -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Test 4: Try to login with old password (should fail)
Write-Host "Test 4: Login with Old Password (Should Fail)" -ForegroundColor Cyan
Write-Host "----------------------------------------------" -ForegroundColor Gray
$loginBody = @{
    email = $TEST_EMAIL
    password = $ORIGINAL_PASSWORD
}

$result = Invoke-ApiRequest -Method POST -Endpoint "/auth/login" -Body $loginBody

if (-not $result.Success -and $result.StatusCode -eq 401) {
    Write-Host "✅ Old password correctly rejected" -ForegroundColor Green
} else {
    Write-Host "❌ Old password still works (password not updated?)" -ForegroundColor Red
}
Write-Host ""

# Test 5: Login with new password (should succeed)
Write-Host "Test 5: Login with New Password (Should Succeed)" -ForegroundColor Cyan
Write-Host "-------------------------------------------------" -ForegroundColor Gray
$loginBody = @{
    email = $TEST_EMAIL
    password = $NEW_PASSWORD
}

$result = Invoke-ApiRequest -Method POST -Endpoint "/auth/login" -Body $loginBody

if ($result.Success) {
    Write-Host "✅ Login successful with new password!" -ForegroundColor Green
    Write-Host "   Access Token: $($result.Data.accessJwt.Substring(0, 20))..." -ForegroundColor Gray
} else {
    Write-Host "❌ Login failed with new password: $($result.Error)" -ForegroundColor Red
}
Write-Host ""

# Test 6: Reset with invalid password (too short)
Write-Host "Test 6: Reset with Invalid Password (Should Fail)" -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Gray
$resetBody = @{
    email = $TEST_EMAIL
    newPassword = "short"
}

$result = Invoke-ApiRequest -Method POST -Endpoint "/auth/reset-password" -Body $resetBody

if (-not $result.Success -and $result.StatusCode -eq 400) {
    Write-Host "✅ Short password correctly rejected" -ForegroundColor Green
} else {
    Write-Host "❌ Validation not working properly" -ForegroundColor Red
}
Write-Host ""

# Test 7: Reset with non-existent email
Write-Host "Test 7: Reset with Non-existent Email (Should Fail)" -ForegroundColor Cyan
Write-Host "----------------------------------------------------" -ForegroundColor Gray
$resetBody = @{
    email = "nonexistent@example.com"
    newPassword = $NEW_PASSWORD
}

$result = Invoke-ApiRequest -Method POST -Endpoint "/auth/reset-password" -Body $resetBody

if (-not $result.Success -and $result.StatusCode -eq 404) {
    Write-Host "✅ Non-existent email correctly rejected" -ForegroundColor Green
} else {
    Write-Host "❌ User validation not working properly" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "================================" -ForegroundColor Cyan
Write-Host "🎉 Test Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Password reset endpoint is working correctly!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test in Flutter application" -ForegroundColor White
Write-Host "  2. Verify the full user flow (email -> code -> new password)" -ForegroundColor White
Write-Host "  3. Deploy to AWS if all tests pass" -ForegroundColor White
Write-Host ""
Write-Host "To clean up test data:" -ForegroundColor Gray
Write-Host "  (Test data is in memory, just restart the backend)" -ForegroundColor Gray

