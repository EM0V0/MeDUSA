# Test Patient Profile API
# This script tests the patient profile management endpoints

$API_BASE = "https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Patient Profile API Test" -ForegroundColor Cyan
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

# Step 3: Create patient profile (via direct DB insert, simulating admin action)
Write-Host "`nTest 3: Create patient profile..." -ForegroundColor Yellow
# Note: In production, this would be done by admin/doctor through a dedicated endpoint
# For now, we'll manually insert via AWS CLI or skip this step
Write-Host "Skipping - would require admin endpoint or direct DB access" -ForegroundColor Gray

# Step 4: Patient gets their own profile
Write-Host "`nTest 4: Patient gets own profile..." -ForegroundColor Yellow
$myProfileResp = curl.exe -X GET "$API_BASE/me/profile" `
    -H "Authorization: Bearer $patientToken" -s

Write-Host "Response: $myProfileResp" -ForegroundColor Gray
if ($myProfileResp -match "PROFILE_NOT_FOUND") {
    Write-Host "Expected: Profile not found (not created yet)" -ForegroundColor Yellow
} else {
    $myProfile = $myProfileResp | ConvertFrom-Json
    if ($myProfile.userId) {
        Write-Host "Success: Got patient profile" -ForegroundColor Green
    } else {
        Write-Host "Failed: $myProfileResp" -ForegroundColor Red
    }
}

# Step 5: Doctor gets patients list (should be empty initially)
Write-Host "`nTest 5: Doctor gets patients list..." -ForegroundColor Yellow
$patientsResp = curl.exe -X GET "$API_BASE/patients" `
    -H "Authorization: Bearer $doctorToken" -s | ConvertFrom-Json

if ($patientsResp.items) {
    Write-Host "Success: Got patients list (count: $($patientsResp.items.Count))" -ForegroundColor Green
} else {
    Write-Host "Failed: $($patientsResp | ConvertTo-Json)" -ForegroundColor Red
}

# Step 6: Register admin
Write-Host "`nTest 6: Register admin..." -ForegroundColor Yellow
$adminEmail = "admin_$(Get-Random)@test.com"
$adminPwd = "AdminPass123!"
$adminBodyObj = @{
    email = $adminEmail
    password = $adminPwd
    role = "admin"
    name = "Admin User"
}
$adminBodyFile = [System.IO.Path]::GetTempFileName()
$adminBodyObj | ConvertTo-Json -Compress | Out-File -FilePath $adminBodyFile -Encoding utf8 -NoNewline

$adminRegResp = curl.exe -X POST "$API_BASE/auth/register" `
    -H "Content-Type: application/json" `
    --data-binary "@$adminBodyFile" -s | ConvertFrom-Json
Remove-Item $adminBodyFile

if ($adminRegResp.accessJwt) {
    Write-Host "Success: Admin registered" -ForegroundColor Green
    $adminToken = $adminRegResp.accessJwt
} else {
    Write-Host "Failed: $($adminRegResp | ConvertTo-Json)" -ForegroundColor Red
    exit 1
}

# Step 7: Admin gets all patients
Write-Host "`nTest 7: Admin gets all patients..." -ForegroundColor Yellow
$allPatientsResp = curl.exe -X GET "$API_BASE/patients" `
    -H "Authorization: Bearer $adminToken" -s | ConvertFrom-Json

if ($allPatientsResp.items) {
    Write-Host "Success: Got all patients (count: $($allPatientsResp.items.Count))" -ForegroundColor Green
} else {
    Write-Host "Failed: $($allPatientsResp | ConvertTo-Json)" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Patient Profile API Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: Full patient profile CRUD requires:" -ForegroundColor Yellow
Write-Host "1. Admin endpoint to create patient profiles" -ForegroundColor Yellow
Write-Host "2. Direct DynamoDB access or registration flow enhancement" -ForegroundColor Yellow

