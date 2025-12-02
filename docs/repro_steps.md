复现实验与验证步骤（适用于 Windows PowerShell）

前提：已安装 Python 3.10+、AWS CLI 已配置（如需访问 AWS 资源）、并在仓库根目录下。

1) 设置环境变量（本地测试）

```powershell
# 设置 JWT secret（示例，仅用于本地测试）
$env:JWT_SECRET = "dev-secret-key-please-change-in-production"
# 可选：设置 token 生命周期（秒）
$env:JWT_EXPIRE_SECONDS = "3600"
$env:REFRESH_TTL_SECONDS = "604800"
```

2) 启动本地后端（如果你使用内置 start script）

```powershell
cd medusa-cloud-components-python-backend\medusa-cloud-components-python-backend\backend-py
.\start_local.ps1
```

3) 在另一个 powershell 中运行演示设备注册脚本（将一条设备写入 DynamoDB 表，用于快速绑定）

```powershell
# 回到仓库根目录
cd D:\25fall\Capstone\ble\MeDUSA
python register_device.py
# 输出示例：Successfully registered device medusa-pi-01 to patient usr_694c4028
```

4) 运行时间戳诊断脚本并收集统计

```powershell
python tools\check_timestamps.py
```

输出将包含：总条目、首/末时间、最小/最大/平均间隔、>1.5s 间隙统计及样本时间戳。

5) 测试 API 授权（示例：调用受保护的 endpoint）

- 从后端的登录接口获取 `accessJwt`（或在 `backend-py` 的测试脚本中直接读取）
- 使用 curl 或 PowerShell `Invoke-RestMethod` 测试受保护 endpoint：

```powershell
$token = "<accessJwt from login>"
Invoke-RestMethod -Uri "https://<api>/api/v1/current-session" -Headers @{ Authorization = "Bearer $token" } -Method Get
```

6) 验证 Authorizer 行为（手工检查）

- 若传入无效或过期的 token，Authorizer 会返回 401（无权访问）。
- 查看 CloudWatch Logs（`lambda_functions/authorizer.py` 的打印）可以看到 token 解码/验证的详细信息（claims、错误原因等）。

安全注意事项：
- 切勿在生产中使用开发 fallback secret。
- 若需要第三方验证或多实例共享验证，请考虑使用 RS256 + JWKS（公私钥对）以便安全地公开公钥。