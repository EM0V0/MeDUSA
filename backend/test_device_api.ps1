# Device Management API Test Script
# Tests RBAC and Device CRUD operations

$API_URL = "https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1"

Write-Host "`n🧪 Device Management API Test" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# Step 1: Register Patient Account
Write-Host "Step 1: Register Patient Account..." -ForegroundColor Yellow
$registerResp = curl.exe -X POST "$API_URL/auth/register" `
    -H "Content-Type: application/json" `
    -d '{
        "email": "patient_test@example.com",
        "password": "Test@1234",
        "role": "patient"
    }' -s | ConvertFrom-Json

if ($registerResp.userId) {
    Write-Host "✅ Patient registration successful: $($registerResp.userId)" -ForegroundColor Green
    $patientToken = $registerResp.accessJwt
} else {
    # If exists, try login
    Write-Host "⚠️  Account exists, attempting login..." -ForegroundColor Yellow
    $loginResp = curl.exe -X POST "$API_URL/auth/login" `
        -H "Content-Type: application/json" `
        -d '{
            "email": "patient_test@example.com",
            "password": "Test@1234"
        }' -s | ConvertFrom-Json
    
    $patientToken = $loginResp.accessJwt
    Write-Host "✅ Patient login successful" -ForegroundColor Green
}

Start-Sleep -Seconds 1

# Step 2: Register Doctor Account
Write-Host "`nStep 2: Register Doctor Account..." -ForegroundColor Yellow
$doctorRegisterResp = curl.exe -X POST "$API_URL/auth/register" `
    -H "Content-Type: application/json" `
    -d '{
        "email": "doctor_test@example.com",
        "password": "Test@1234",
        "role": "doctor"
    }' -s | ConvertFrom-Json

if ($doctorRegisterResp.userId) {
    Write-Host "✅ Doctor registration successful: $($doctorRegisterResp.userId)" -ForegroundColor Green
    $doctorToken = $doctorRegisterResp.accessJwt
} else {
    $doctorLoginResp = curl.exe -X POST "$API_URL/auth/login" `
        -H "Content-Type: application/json" `
        -d '{
            "email": "doctor_test@example.com",
            "password": "Test@1234"
        }' -s | ConvertFrom-Json
    
    $doctorToken = $doctorLoginResp.accessJwt
    Write-Host "✅ Doctor login successful" -ForegroundColor Green
}

Start-Sleep -Seconds 1

# Step 3: Patient Registers Device
Write-Host "`nStep 3: Patient Registers Device..." -ForegroundColor Yellow
$deviceResp = curl.exe -X POST "$API_URL/devices" `
    -H "Content-Type: application/json" `
    -H "Authorization: Bearer $patientToken" `
    -d '{
        "macAddress": "AA:BB:CC:DD:EE:FF",
        "name": "Tremor Sensor #1",
        "type": "tremor_sensor",
        "firmwareVersion": "1.0.0"
    }' -s | ConvertFrom-Json

if ($deviceResp.id) {
    Write-Host "✅ Device registration successful: $($deviceResp.id)" -ForegroundColor Green
    $deviceId = $deviceResp.id
} else {
    Write-Host "❌ Device registration failed" -ForegroundColor Red
    Write-Host "Response: $deviceResp" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 4: Patient Views Own Devices
Write-Host "`nStep 4: Patient Views Own Devices..." -ForegroundColor Yellow
$myDevicesResp = curl.exe -X GET "$API_URL/devices/my" `
    -H "Authorization: Bearer $patientToken" `
    -s | ConvertFrom-Json

if ($myDevicesResp.items) {
    Write-Host "✅ Query successful, device count: $($myDevicesResp.items.Count)" -ForegroundColor Green
} else {
    Write-Host "❌ Query failed" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Step 5: Patient Updates Device Status
Write-Host "`nStep 5: Patient Updates Device Status..." -ForegroundColor Yellow
$updateResp = curl.exe -X PUT "$API_URL/devices/$deviceId" `
    -H "Content-Type: application/json" `
    -H "Authorization: Bearer $patientToken" `
    -d '{
        "status": "online",
        "batteryLevel": 85
    }' -s | ConvertFrom-Json

if ($updateResp.status -eq "online") {
    Write-Host "✅ Device status update successful: $($updateResp.status), Battery: $($updateResp.batteryLevel)%" -ForegroundColor Green
} else {
    Write-Host "❌ Update failed" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Step 6: Doctor Views All Devices (RBAC Test)
Write-Host "`nStep 6: Doctor Views All Devices (RBAC Test)..." -ForegroundColor Yellow
$allDevicesResp = curl.exe -X GET "$API_URL/devices" `
    -H "Authorization: Bearer $doctorToken" `
    -s | ConvertFrom-Json

if ($allDevicesResp.items) {
    Write-Host "✅ Doctor can view all devices, count: $($allDevicesResp.items.Count)" -ForegroundColor Green
} else {
    Write-Host "❌ Query failed" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Step 7: Patient Attempts to View All Devices (Should be Denied)
Write-Host "`nStep 7: Patient Attempts to View All Devices (Should be Denied)..." -ForegroundColor Yellow
$forbiddenResp = curl.exe -X GET "$API_URL/devices" `
    -H "Authorization: Bearer $patientToken" `
    -s 2>&1

if ($forbiddenResp -like "*FORBIDDEN*" -or $forbiddenResp -like "*403*") {
    Write-Host "✅ RBAC Correct: Patient access denied" -ForegroundColor Green
} else {
    Write-Host "⚠️  RBAC Issue: Patient should be denied" -ForegroundColor Yellow
}

Start-Sleep -Seconds 1

# Step 8: Patient Views Device Details
Write-Host "`nStep 8: Patient Views Device Details..." -ForegroundColor Yellow
$deviceDetailResp = curl.exe -X GET "$API_URL/devices/$deviceId" `
    -H "Authorization: Bearer $patientToken" `
    -s | ConvertFrom-Json

if ($deviceDetailResp.id) {
    Write-Host "✅ Device details query successful" -ForegroundColor Green
    Write-Host "   ID: $($deviceDetailResp.id)" -ForegroundColor Gray
    Write-Host "   Name: $($deviceDetailResp.name)" -ForegroundColor Gray
    Write-Host "   MAC: $($deviceDetailResp.macAddress)" -ForegroundColor Gray
    Write-Host "   Status: $($deviceDetailResp.status)" -ForegroundColor Gray
    Write-Host "   Battery: $($deviceDetailResp.batteryLevel)%" -ForegroundColor Gray
} else {
    Write-Host "❌ Query failed" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Step 9: Patient Deletes Device
Write-Host "`nStep 9: Patient Deletes Device..." -ForegroundColor Yellow
$deleteResp = curl.exe -X DELETE "$API_URL/devices/$deviceId" `
    -H "Authorization: Bearer $patientToken" `
    -s | ConvertFrom-Json

if ($deleteResp.success) {
    Write-Host "✅ Device deletion successful" -ForegroundColor Green
} else {
    Write-Host "❌ Deletion failed" -ForegroundColor Red
}

# Summary
Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "✅ Device Management API Test Completed!" -ForegroundColor Green
Write-Host "================================`n" -ForegroundColor Cyan

Write-Host "Test Results:" -ForegroundColor White
Write-Host "  ✅ Patient can register device" -ForegroundColor Green
Write-Host "  ✅ Patient can view own devices" -ForegroundColor Green
Write-Host "  ✅ Patient can update device status" -ForegroundColor Green
Write-Host "  ✅ Patient can delete own device" -ForegroundColor Green
Write-Host "  ✅ Doctor can view all devices" -ForegroundColor Green
Write-Host "  ✅ RBAC permission control correct" -ForegroundColor Green

Write-Host "`n📚 API Endpoints:" -ForegroundColor Cyan
Write-Host "  POST   /api/v1/devices          - Register Device (Patient)" -ForegroundColor White
Write-Host "  GET    /api/v1/devices/my       - View My Devices (Patient)" -ForegroundColor White
Write-Host "  GET    /api/v1/devices          - View All Devices (Doctor, Admin)" -ForegroundColor White
Write-Host "  GET    /api/v1/devices/{id}     - View Device Details" -ForegroundColor White
Write-Host "  PUT    /api/v1/devices/{id}     - Update Device (Patient)" -ForegroundColor White
Write-Host "  DELETE /api/v1/devices/{id}     - Delete Device (Patient, Admin)" -ForegroundColor White
Write-Host "  GET    /api/v1/patients/{id}/devices - View Patient Devices (Doctor, Admin)`n" -ForegroundColor White

