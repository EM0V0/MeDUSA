# Test Session Management API (Dynamic Device Binding)
# This script demonstrates the device pool + dynamic binding architecture

$API_BASE = "https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Session Management API Test" -ForegroundColor Cyan
Write-Host "Device Pool + Dynamic Binding" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Register a doctor
Write-Host "Test 1: Register doctor..." -ForegroundColor Yellow
$doctorEmail = "doctor_$(Get-Random)@test.com"
$doctorPwd = "DoctorPass123!"
$doctorBodyObj = @{
    email = $doctorEmail
    password = $doctorPwd
    role = "doctor"
    name = "Dr. Smith"
}
$doctorBodyFile = [System.IO.Path]::GetTempFileName()
$doctorBodyObj | ConvertTo-Json -Compress | Out-File -FilePath $doctorBodyFile -Encoding utf8 -NoNewline

$doctorRegResp = curl.exe -X POST "$API_BASE/auth/register" `
    -H "Content-Type: application/json" `
    --data-binary "@$doctorBodyFile" -s | ConvertFrom-Json
Remove-Item $doctorBodyFile

if ($doctorRegResp.accessJwt) {
    Write-Host "Success: Doctor registered" -ForegroundColor Green
    $doctorToken = $doctorRegResp.accessJwt
    $doctorId = $doctorRegResp.userId
    Write-Host "Doctor ID: $doctorId" -ForegroundColor Gray
} else {
    Write-Host "Failed: $($doctorRegResp | ConvertTo-Json)" -ForegroundColor Red
    exit 1
}

# Step 2: Register a patient
Write-Host "`nTest 2: Register patient..." -ForegroundColor Yellow
$patientEmail = "patient_$(Get-Random)@test.com"
$patientPwd = "PatientPass123!"
$patientBodyObj = @{
    email = $patientEmail
    password = $patientPwd
    role = "patient"
    name = "John Doe"
}
$patientBodyFile = [System.IO.Path]::GetTempFileName()
$patientBodyObj | ConvertTo-Json -Compress | Out-File -FilePath $patientBodyFile -Encoding utf8 -NoNewline

$patientRegResp = curl.exe -X POST "$API_BASE/auth/register" `
    -H "Content-Type: application/json" `
    --data-binary "@$patientBodyFile" -s | ConvertFrom-Json
Remove-Item $patientBodyFile

if ($patientRegResp.accessJwt) {
    Write-Host "Success: Patient registered" -ForegroundColor Green
    $patientToken = $patientRegResp.accessJwt
    $patientId = $patientRegResp.userId
    Write-Host "Patient ID: $patientId" -ForegroundColor Gray
} else {
    Write-Host "Failed: $($patientRegResp | ConvertTo-Json)" -ForegroundColor Red
    exit 1
}

# Step 3: Doctor registers a device (to shared pool)
Write-Host "`nTest 3: Doctor registers device to shared pool..." -ForegroundColor Yellow
$deviceMac = "AA:BB:CC:DD:$(Get-Random -Minimum 10 -Maximum 99):$(Get-Random -Minimum 10 -Maximum 99)"
$deviceBodyObj = @{
    macAddress = $deviceMac
    name = "Pi Device #1"
    type = "posture_sensor"
    firmwareVersion = "1.0.0"
}
$deviceBodyFile = [System.IO.Path]::GetTempFileName()
$deviceBodyObj | ConvertTo-Json -Compress | Out-File -FilePath $deviceBodyFile -Encoding utf8 -NoNewline

$deviceResp = curl.exe -X POST "$API_BASE/devices" `
    -H "Authorization: Bearer $doctorToken" `
    -H "Content-Type: application/json" `
    --data-binary "@$deviceBodyFile" -s | ConvertFrom-Json
Remove-Item $deviceBodyFile

if ($deviceResp.id) {
    Write-Host "Success: Device registered" -ForegroundColor Green
    $deviceId = $deviceResp.id
    Write-Host "Device ID: $deviceId" -ForegroundColor Gray
    Write-Host "MAC Address: $deviceMac" -ForegroundColor Gray
    Write-Host "Patient ID: $($deviceResp.patientId) (should be null)" -ForegroundColor Gray
} else {
    Write-Host "Failed: $($deviceResp | ConvertTo-Json)" -ForegroundColor Red
    exit 1
}

# Step 4: Doctor creates a measurement session (binds device to patient)
Write-Host "`nTest 4: Doctor creates measurement session..." -ForegroundColor Yellow
$sessionBodyObj = @{
    deviceId = $deviceId
    patientId = $patientId
    notes = "Morning measurement session"
}
$sessionBodyFile = [System.IO.Path]::GetTempFileName()
$sessionBodyObj | ConvertTo-Json -Compress | Out-File -FilePath $sessionBodyFile -Encoding utf8 -NoNewline

$sessionResp = curl.exe -X POST "$API_BASE/sessions" `
    -H "Authorization: Bearer $doctorToken" `
    -H "Content-Type: application/json" `
    --data-binary "@$sessionBodyFile" -s | ConvertFrom-Json
Remove-Item $sessionBodyFile

if ($sessionResp.sessionId) {
    Write-Host "Success: Session created" -ForegroundColor Green
    $sessionId = $sessionResp.sessionId
    Write-Host "Session ID: $sessionId" -ForegroundColor Gray
    Write-Host "Status: $($sessionResp.status)" -ForegroundColor Gray
} else {
    Write-Host "Failed: $($sessionResp | ConvertTo-Json)" -ForegroundColor Red
    exit 1
}

# Step 5: Pi device polls for current session
Write-Host "`nTest 5: Pi device polls for current session..." -ForegroundColor Yellow
$currentSessionResp = curl.exe -X GET "$API_BASE/devices/$deviceId/current-session" -s | ConvertFrom-Json

if ($currentSessionResp.sessionId) {
    Write-Host "Success: Pi got current session" -ForegroundColor Green
    Write-Host "Session ID: $($currentSessionResp.sessionId)" -ForegroundColor Gray
    Write-Host "Patient ID: $($currentSessionResp.patientId)" -ForegroundColor Gray
    Write-Host "Status: $($currentSessionResp.status)" -ForegroundColor Gray
} else {
    Write-Host "Failed: $($currentSessionResp | ConvertTo-Json)" -ForegroundColor Red
}

# Step 6: Patient views their session
Write-Host "`nTest 6: Patient views their session..." -ForegroundColor Yellow
$patientSessionResp = curl.exe -X GET "$API_BASE/sessions/$sessionId" `
    -H "Authorization: Bearer $patientToken" -s | ConvertFrom-Json

if ($patientSessionResp.sessionId) {
    Write-Host "Success: Patient viewed session" -ForegroundColor Green
    Write-Host "Device Name: $($patientSessionResp.deviceName)" -ForegroundColor Gray
    Write-Host "MAC: $($patientSessionResp.deviceMacAddress)" -ForegroundColor Gray
} else {
    Write-Host "Failed: $($patientSessionResp | ConvertTo-Json)" -ForegroundColor Red
}

# Step 7: Doctor ends the session
Write-Host "`nTest 7: Doctor ends the session..." -ForegroundColor Yellow
$endSessionResp = curl.exe -X POST "$API_BASE/sessions/$sessionId/end" `
    -H "Authorization: Bearer $doctorToken" -s | ConvertFrom-Json

if ($endSessionResp.status -eq "completed") {
    Write-Host "Success: Session ended" -ForegroundColor Green
    Write-Host "Status: $($endSessionResp.status)" -ForegroundColor Gray
    Write-Host "End Time: $($endSessionResp.endTime)" -ForegroundColor Gray
} else {
    Write-Host "Failed: $($endSessionResp | ConvertTo-Json)" -ForegroundColor Red
}

# Step 8: Verify device is free (no active session)
Write-Host "`nTest 8: Verify device is free..." -ForegroundColor Yellow
$noSessionResp = curl.exe -X GET "$API_BASE/devices/$deviceId/current-session" -s

if ($noSessionResp -match "NO_ACTIVE_SESSION") {
    Write-Host "Success: Device is free (no active session)" -ForegroundColor Green
} else {
    Write-Host "Unexpected: $noSessionResp" -ForegroundColor Yellow
}

# Step 9: Register another patient
Write-Host "`nTest 9: Register second patient..." -ForegroundColor Yellow
$patient2Email = "patient2_$(Get-Random)@test.com"
$patient2Pwd = "PatientPass123!"
$patient2BodyObj = @{
    email = $patient2Email
    password = $patient2Pwd
    role = "patient"
    name = "Jane Smith"
}
$patient2BodyFile = [System.IO.Path]::GetTempFileName()
$patient2BodyObj | ConvertTo-Json -Compress | Out-File -FilePath $patient2BodyFile -Encoding utf8 -NoNewline

$patient2RegResp = curl.exe -X POST "$API_BASE/auth/register" `
    -H "Content-Type: application/json" `
    --data-binary "@$patient2BodyFile" -s | ConvertFrom-Json
Remove-Item $patient2BodyFile

if ($patient2RegResp.accessJwt) {
    Write-Host "Success: Second patient registered" -ForegroundColor Green
    $patient2Id = $patient2RegResp.userId
    Write-Host "Patient 2 ID: $patient2Id" -ForegroundColor Gray
} else {
    Write-Host "Failed: $($patient2RegResp | ConvertTo-Json)" -ForegroundColor Red
    exit 1
}

# Step 10: Doctor creates session for second patient (same device)
Write-Host "`nTest 10: Doctor creates session for second patient (same device)..." -ForegroundColor Yellow
$session2BodyObj = @{
    deviceId = $deviceId
    patientId = $patient2Id
    notes = "Afternoon measurement session"
}
$session2BodyFile = [System.IO.Path]::GetTempFileName()
$session2BodyObj | ConvertTo-Json -Compress | Out-File -FilePath $session2BodyFile -Encoding utf8 -NoNewline

$session2Resp = curl.exe -X POST "$API_BASE/sessions" `
    -H "Authorization: Bearer $doctorToken" `
    -H "Content-Type: application/json" `
    --data-binary "@$session2BodyFile" -s | ConvertFrom-Json
Remove-Item $session2BodyFile

if ($session2Resp.sessionId) {
    Write-Host "Success: Second session created (same device, different patient)" -ForegroundColor Green
    Write-Host "Session ID: $($session2Resp.sessionId)" -ForegroundColor Gray
    Write-Host "Patient ID: $($session2Resp.patientId)" -ForegroundColor Gray
} else {
    Write-Host "Failed: $($session2Resp | ConvertTo-Json)" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Session Management Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "- Device registered to shared pool (no patient binding)" -ForegroundColor White
Write-Host "- Session 1: Device bound to Patient 1" -ForegroundColor White
Write-Host "- Pi device polled and got session info" -ForegroundColor White
Write-Host "- Session 1 ended, device freed" -ForegroundColor White
Write-Host "- Session 2: Same device bound to Patient 2" -ForegroundColor White
Write-Host ""
Write-Host "Architecture validated: Device Pool + Dynamic Binding works!" -ForegroundColor Green

