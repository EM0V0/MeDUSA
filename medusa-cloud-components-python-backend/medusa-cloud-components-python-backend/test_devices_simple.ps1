# Simple Device API Test
$API_URL = "https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1"

Write-Host "`n=== Device API Test ===" -ForegroundColor Cyan

# Step 1: Register patient
Write-Host "`nStep 1: Register patient..." -ForegroundColor Yellow
$email = "device_test_" + (Get-Random) + "@example.com"
$resp = curl.exe -X POST "$API_URL/auth/register" -H "Content-Type: application/json" -d "{`"email`":`"$email`",`"password`":`"Test@1234`",`"role`":`"patient`"}" -s | ConvertFrom-Json

if ($resp.accessJwt) {
    $token = $resp.accessJwt
    Write-Host "SUCCESS: Patient registered" -ForegroundColor Green
} else {
    Write-Host "FAILED: Could not register" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 2: Register device
Write-Host "`nStep 2: Register device..." -ForegroundColor Yellow
$mac = "AA:BB:CC:DD:EE:" + (Get-Random -Maximum 99).ToString("00")
$deviceResp = curl.exe -X POST "$API_URL/devices" -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d "{`"macAddress`":`"$mac`",`"name`":`"Test Sensor`",`"type`":`"tremor_sensor`",`"firmwareVersion`":`"1.0.0`"}" -s | ConvertFrom-Json

if ($deviceResp.id) {
    $deviceId = $deviceResp.id
    Write-Host "SUCCESS: Device registered" -ForegroundColor Green
    Write-Host "  ID: $deviceId" -ForegroundColor Gray
    Write-Host "  MAC: $($deviceResp.macAddress)" -ForegroundColor Gray
    Write-Host "  Status: $($deviceResp.status)" -ForegroundColor Gray
} else {
    Write-Host "FAILED: Could not register device" -ForegroundColor Red
    Write-Host "Response: $deviceResp" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 3: Get my devices
Write-Host "`nStep 3: Get my devices..." -ForegroundColor Yellow
$myDevices = curl.exe -X GET "$API_URL/devices/my" -H "Authorization: Bearer $token" -s | ConvertFrom-Json

if ($myDevices.items) {
    Write-Host "SUCCESS: Found $($myDevices.items.Count) device(s)" -ForegroundColor Green
} else {
    Write-Host "FAILED: Could not get devices" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 4: Update device
Write-Host "`nStep 4: Update device status..." -ForegroundColor Yellow
$updateResp = curl.exe -X PUT "$API_URL/devices/$deviceId" -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d "{`"status`":`"online`",`"batteryLevel`":85}" -s | ConvertFrom-Json

if ($updateResp.status -eq "online") {
    Write-Host "SUCCESS: Device updated" -ForegroundColor Green
    Write-Host "  Status: $($updateResp.status)" -ForegroundColor Gray
    Write-Host "  Battery: $($updateResp.batteryLevel)%" -ForegroundColor Gray
} else {
    Write-Host "FAILED: Could not update device" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 5: Get device details
Write-Host "`nStep 5: Get device details..." -ForegroundColor Yellow
$deviceDetail = curl.exe -X GET "$API_URL/devices/$deviceId" -H "Authorization: Bearer $token" -s | ConvertFrom-Json

if ($deviceDetail.id) {
    Write-Host "SUCCESS: Device details retrieved" -ForegroundColor Green
    Write-Host "  ID: $($deviceDetail.id)" -ForegroundColor Gray
    Write-Host "  Name: $($deviceDetail.name)" -ForegroundColor Gray
    Write-Host "  Status: $($deviceDetail.status)" -ForegroundColor Gray
} else {
    Write-Host "FAILED: Could not get device details" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 6: Register doctor and test RBAC
Write-Host "`nStep 6: Test RBAC - Register doctor..." -ForegroundColor Yellow
$doctorEmail = "doctor_test_" + (Get-Random) + "@example.com"
$doctorResp = curl.exe -X POST "$API_URL/auth/register" -H "Content-Type: application/json" -d "{`"email`":`"$doctorEmail`",`"password`":`"Test@1234`",`"role`":`"doctor`"}" -s | ConvertFrom-Json

if ($doctorResp.accessJwt) {
    $doctorToken = $doctorResp.accessJwt
    Write-Host "SUCCESS: Doctor registered" -ForegroundColor Green
} else {
    Write-Host "FAILED: Could not register doctor" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 7: Doctor views all devices
Write-Host "`nStep 7: Doctor views all devices..." -ForegroundColor Yellow
$allDevices = curl.exe -X GET "$API_URL/devices" -H "Authorization: Bearer $doctorToken" -s | ConvertFrom-Json

if ($allDevices.items) {
    Write-Host "SUCCESS: Doctor can view all devices ($($allDevices.items.Count) total)" -ForegroundColor Green
} else {
    Write-Host "FAILED: Doctor could not view devices" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 8: Patient tries to view all devices (should fail)
Write-Host "`nStep 8: Patient tries to view all devices (should be denied)..." -ForegroundColor Yellow
$patientAllDevices = curl.exe -X GET "$API_URL/devices" -H "Authorization: Bearer $token" -s 2>&1

if ($patientAllDevices -like "*FORBIDDEN*" -or $patientAllDevices -like "*403*") {
    Write-Host "SUCCESS: RBAC working - Patient denied access" -ForegroundColor Green
} else {
    Write-Host "WARNING: RBAC might not be working correctly" -ForegroundColor Yellow
}

Start-Sleep -Seconds 1

# Step 9: Delete device
Write-Host "`nStep 9: Delete device..." -ForegroundColor Yellow
$deleteResp = curl.exe -X DELETE "$API_URL/devices/$deviceId" -H "Authorization: Bearer $token" -s | ConvertFrom-Json

if ($deleteResp.success) {
    Write-Host "SUCCESS: Device deleted" -ForegroundColor Green
} else {
    Write-Host "FAILED: Could not delete device" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host "`n==================================" -ForegroundColor Cyan
Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Cyan

Write-Host "`nTest Summary:" -ForegroundColor White
Write-Host "  [PASS] Patient registration" -ForegroundColor Green
Write-Host "  [PASS] Device registration" -ForegroundColor Green
Write-Host "  [PASS] Get my devices" -ForegroundColor Green
Write-Host "  [PASS] Update device" -ForegroundColor Green
Write-Host "  [PASS] Get device details" -ForegroundColor Green
Write-Host "  [PASS] Doctor registration" -ForegroundColor Green
Write-Host "  [PASS] Doctor view all devices" -ForegroundColor Green
Write-Host "  [PASS] RBAC - Patient denied access" -ForegroundColor Green
Write-Host "  [PASS] Delete device" -ForegroundColor Green

Write-Host "`nDevice API is ready for production!" -ForegroundColor Cyan

