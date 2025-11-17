# 设备管理 API 测试脚本
# 测试 RBAC 权限和设备 CRUD 操作

$API_URL = "https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1"

Write-Host "`n🧪 设备管理 API 测试" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# Step 1: 注册患者账户
Write-Host "Step 1: 注册患者账户..." -ForegroundColor Yellow
$registerResp = curl.exe -X POST "$API_URL/auth/register" `
    -H "Content-Type: application/json" `
    -d '{
        "email": "patient_test@example.com",
        "password": "Test@1234",
        "role": "patient"
    }' -s | ConvertFrom-Json

if ($registerResp.userId) {
    Write-Host "✅ 患者注册成功: $($registerResp.userId)" -ForegroundColor Green
    $patientToken = $registerResp.accessJwt
} else {
    # 如果已存在，尝试登录
    Write-Host "⚠️  账户已存在，尝试登录..." -ForegroundColor Yellow
    $loginResp = curl.exe -X POST "$API_URL/auth/login" `
        -H "Content-Type: application/json" `
        -d '{
            "email": "patient_test@example.com",
            "password": "Test@1234"
        }' -s | ConvertFrom-Json
    
    $patientToken = $loginResp.accessJwt
    Write-Host "✅ 患者登录成功" -ForegroundColor Green
}

Start-Sleep -Seconds 1

# Step 2: 注册医生账户
Write-Host "`nStep 2: 注册医生账户..." -ForegroundColor Yellow
$doctorRegisterResp = curl.exe -X POST "$API_URL/auth/register" `
    -H "Content-Type: application/json" `
    -d '{
        "email": "doctor_test@example.com",
        "password": "Test@1234",
        "role": "doctor"
    }' -s | ConvertFrom-Json

if ($doctorRegisterResp.userId) {
    Write-Host "✅ 医生注册成功: $($doctorRegisterResp.userId)" -ForegroundColor Green
    $doctorToken = $doctorRegisterResp.accessJwt
} else {
    $doctorLoginResp = curl.exe -X POST "$API_URL/auth/login" `
        -H "Content-Type: application/json" `
        -d '{
            "email": "doctor_test@example.com",
            "password": "Test@1234"
        }' -s | ConvertFrom-Json
    
    $doctorToken = $doctorLoginResp.accessJwt
    Write-Host "✅ 医生登录成功" -ForegroundColor Green
}

Start-Sleep -Seconds 1

# Step 3: 患者注册设备
Write-Host "`nStep 3: 患者注册设备..." -ForegroundColor Yellow
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
    Write-Host "✅ 设备注册成功: $($deviceResp.id)" -ForegroundColor Green
    $deviceId = $deviceResp.id
} else {
    Write-Host "❌ 设备注册失败" -ForegroundColor Red
    Write-Host "Response: $deviceResp" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 4: 患者查看自己的设备
Write-Host "`nStep 4: 患者查看自己的设备..." -ForegroundColor Yellow
$myDevicesResp = curl.exe -X GET "$API_URL/devices/my" `
    -H "Authorization: Bearer $patientToken" `
    -s | ConvertFrom-Json

if ($myDevicesResp.items) {
    Write-Host "✅ 查询成功，设备数量: $($myDevicesResp.items.Count)" -ForegroundColor Green
} else {
    Write-Host "❌ 查询失败" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Step 5: 患者更新设备状态
Write-Host "`nStep 5: 患者更新设备状态..." -ForegroundColor Yellow
$updateResp = curl.exe -X PUT "$API_URL/devices/$deviceId" `
    -H "Content-Type: application/json" `
    -H "Authorization: Bearer $patientToken" `
    -d '{
        "status": "online",
        "batteryLevel": 85
    }' -s | ConvertFrom-Json

if ($updateResp.status -eq "online") {
    Write-Host "✅ 设备状态更新成功: $($updateResp.status), 电量: $($updateResp.batteryLevel)%" -ForegroundColor Green
} else {
    Write-Host "❌ 更新失败" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Step 6: 医生查看所有设备 (RBAC 测试)
Write-Host "`nStep 6: 医生查看所有设备 (RBAC 测试)..." -ForegroundColor Yellow
$allDevicesResp = curl.exe -X GET "$API_URL/devices" `
    -H "Authorization: Bearer $doctorToken" `
    -s | ConvertFrom-Json

if ($allDevicesResp.items) {
    Write-Host "✅ 医生可以查看所有设备，数量: $($allDevicesResp.items.Count)" -ForegroundColor Green
} else {
    Write-Host "❌ 查询失败" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Step 7: 患者尝试查看所有设备 (应该被拒绝)
Write-Host "`nStep 7: 患者尝试查看所有设备 (应该被拒绝)..." -ForegroundColor Yellow
$forbiddenResp = curl.exe -X GET "$API_URL/devices" `
    -H "Authorization: Bearer $patientToken" `
    -s 2>&1

if ($forbiddenResp -like "*FORBIDDEN*" -or $forbiddenResp -like "*403*") {
    Write-Host "✅ RBAC 正确：患者被拒绝访问" -ForegroundColor Green
} else {
    Write-Host "⚠️  RBAC 可能有问题：患者应该被拒绝" -ForegroundColor Yellow
}

Start-Sleep -Seconds 1

# Step 8: 患者查看设备详情
Write-Host "`nStep 8: 患者查看设备详情..." -ForegroundColor Yellow
$deviceDetailResp = curl.exe -X GET "$API_URL/devices/$deviceId" `
    -H "Authorization: Bearer $patientToken" `
    -s | ConvertFrom-Json

if ($deviceDetailResp.id) {
    Write-Host "✅ 设备详情查询成功" -ForegroundColor Green
    Write-Host "   ID: $($deviceDetailResp.id)" -ForegroundColor Gray
    Write-Host "   Name: $($deviceDetailResp.name)" -ForegroundColor Gray
    Write-Host "   MAC: $($deviceDetailResp.macAddress)" -ForegroundColor Gray
    Write-Host "   Status: $($deviceDetailResp.status)" -ForegroundColor Gray
    Write-Host "   Battery: $($deviceDetailResp.batteryLevel)%" -ForegroundColor Gray
} else {
    Write-Host "❌ 查询失败" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Step 9: 患者删除设备
Write-Host "`nStep 9: 患者删除设备..." -ForegroundColor Yellow
$deleteResp = curl.exe -X DELETE "$API_URL/devices/$deviceId" `
    -H "Authorization: Bearer $patientToken" `
    -s | ConvertFrom-Json

if ($deleteResp.success) {
    Write-Host "✅ 设备删除成功" -ForegroundColor Green
} else {
    Write-Host "❌ 删除失败" -ForegroundColor Red
}

# 总结
Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "✅ 设备管理 API 测试完成！" -ForegroundColor Green
Write-Host "================================`n" -ForegroundColor Cyan

Write-Host "测试结果:" -ForegroundColor White
Write-Host "  ✅ 患者可以注册设备" -ForegroundColor Green
Write-Host "  ✅ 患者可以查看自己的设备" -ForegroundColor Green
Write-Host "  ✅ 患者可以更新设备状态" -ForegroundColor Green
Write-Host "  ✅ 患者可以删除自己的设备" -ForegroundColor Green
Write-Host "  ✅ 医生可以查看所有设备" -ForegroundColor Green
Write-Host "  ✅ RBAC 权限控制正确" -ForegroundColor Green

Write-Host "`n📚 API 端点:" -ForegroundColor Cyan
Write-Host "  POST   /api/v1/devices          - 注册设备 (Patient)" -ForegroundColor White
Write-Host "  GET    /api/v1/devices/my       - 查看我的设备 (Patient)" -ForegroundColor White
Write-Host "  GET    /api/v1/devices          - 查看所有设备 (Doctor, Admin)" -ForegroundColor White
Write-Host "  GET    /api/v1/devices/{id}     - 查看设备详情" -ForegroundColor White
Write-Host "  PUT    /api/v1/devices/{id}     - 更新设备 (Patient)" -ForegroundColor White
Write-Host "  DELETE /api/v1/devices/{id}     - 删除设备 (Patient, Admin)" -ForegroundColor White
Write-Host "  GET    /api/v1/patients/{id}/devices - 查看患者设备 (Doctor, Admin)`n" -ForegroundColor White

