本文件包含可直接替换到论文中的段落（中文与学术英文两套），并指明建议放置的位置（章节/小节）。请把相应语言版本粘贴到论文对应位置并替换原文。

使用说明：每一条以“目标位置”开头，随后给出“替换文本（中文）”和“替换文本（英文）”。英文版本已润色为学术风格，可直接用于投稿稿件。

---

位置：Methods → Authentication（或 Abstract 中认证一小节）

替换文本（中文）：
认证与会话管理：系统采用基于 JSON Web Token (JWT) 的访问控制，由 PyJWT 负责令牌的签发与验证；密码使用 Argon2id 进行哈希存储以增强对离线暴力破解的抵抗力。访问令牌采用对称签名算法 HS256，签名密钥通过环境变量 `JWT_SECRET` 提供；在生产环境中该密钥应从 AWS Secrets Manager 注入并定期轮换（参见 `template.yaml`）。系统还发放刷新令牌并对访问令牌设置较短有效期以减少滥用风险（实现参考：`medusa-cloud-components-python-backend/backend-py/auth.py` 中的 `issue_tokens` 与 `verify_jwt`）。

替换文本（英文）：
Authentication and session management: The system uses JSON Web Tokens (JWT) for API access control. Tokens are issued and verified using PyJWT; passwords are hashed with Argon2id to mitigate offline brute-force attacks. Access tokens are signed with HS256 using a secret provided via the `JWT_SECRET` environment variable; in production this secret is injected from AWS Secrets Manager and should be rotated regularly (see `template.yaml`). Refresh tokens are issued and access tokens are kept short-lived to limit abuse (implementation: `backend-py/auth.py`).

---

位置：Methods → API / Authorization（Authorizer 细节）

替换文本（中文）：
API Gateway 在前端部署了一个 Lambda Token Authorizer（实现见 `lambda_functions/authorizer.py`）。Authorizer 从事件的 `authorizationToken` 字段读取 Bearer token（若包含 'Bearer ' 前缀则移除），使用 `JWT_SECRET` 并以 HS256 验证 token（代码片段：`jwt.decode(token, JWT_SECRET, algorithms=['HS256'])`）。验证通过后，Authorizer 返回一个 IAM policy document；当前实现为简化测试对 API 使用通配符资源（`/*/*`），应用级别的细粒度访问控制通过 token 中的 `role` claim 在后端执行。建议在论文中补充：生产系统应严格验证标准 claim（如 `iss` 与 `aud`），并实现 token 撤销（例如 `jti` 黑名单）以支持即时注销。

替换文本（英文）：
We deploy a Lambda Token Authorizer at API Gateway (`lambda_functions/authorizer.py`). The Authorizer reads the bearer token from the event's `authorizationToken` field (stripping the `Bearer ` prefix when present) and verifies it using `JWT_SECRET` with HS256 (`jwt.decode(...)`). Upon successful verification it returns an IAM policy document; the current implementation uses wildcard resources for simplicity, while application-level role-based access control is enforced using the token's `role` claim. For production, the Authorizer and backend should strictly validate standard claims (e.g. `iss` and `aud`) and implement token revocation mechanisms (e.g. a `jti` blacklist) to support immediate revocation.

---

位置：Methods → Device Onboarding / Implementation Details

替换文本（中文）：
设备注册：仓库包含演示用脚本 `register_device.py`，该脚本直接向 DynamoDB 表 `medusa-devices-prod` 写入示例设备记录以便本地或开发环境快速测试。论文中请勿把此脚本描述为生产级引导。生产环境应采用 AWS IoT 的 X.509 证书、Fleet/Just-In-Time Provisioning 或受控注册 API，以保证设备可验证身份及最小权限准入。

替换文本（英文）：
Device registration: The repository includes a demo script (`register_device.py`) that writes a sample device entry into DynamoDB (`medusa-devices-prod`) for development/testing. Do not describe this script as a production provisioning mechanism. Production device onboarding should use AWS IoT X.509 certificates and fleet provisioning to ensure verifiable device identity and least-privilege admission.

---

位置：Results / Data Quality → Timestamp Handling（若论文宣称“修复时间戳问题”）

替换文本（中文）：
时间戳一致性验证：为验证时序数据的完整性与间隙，我们统一采用 ISO8601 UTC（带尾部 Z）格式并提供诊断脚本 `tools/check_timestamps.py`。该脚本会输出统计摘要：总样本数、首/末时间、最小/最大/平均间隔，以及间隙大于 1.5s 的计数与示例条目。建议在论文中附上该脚本的输出摘要表格并说明运行命令（例如 `python tools/check_timestamps.py`）与运行环境，以便读者复现验证结果。

示例占位表格（请用真实运行结果替换）：
| Metric | Value |
|---|---|
| Total timestamps | 12,345 |
| First timestamp | 2025-11-01T00:00:00Z |
| Last timestamp | 2025-11-07T23:59:59Z |
| Min interval (s) | 0.02 |
| Max interval (s) | 120.3 |
| Mean interval (s) | 0.98 |
| Gaps >1.5s | 37 |

替换文本（英文）：
Timestamp consistency validation: To validate temporal integrity and gaps in time-series data, we standardize timestamps to ISO8601 UTC (trailing Z) and provide a diagnostic script (`tools/check_timestamps.py`). The script outputs summary statistics: total samples, first/last timestamps, min/max/mean intervals, and the count/list of gaps larger than 1.5s. We recommend including the script's output table in the manuscript and specifying the exact command used (e.g. `python tools/check_timestamps.py`) and runtime environment so readers can reproduce the validation.

---

位置：Methods → Authorization / RBAC（若论文宣称“API 层实现 RBAC”）

替换文本（中文）：
RBAC 实现说明：系统在应用层基于 token 中的 `role` claim 实现角色权限控制（RBAC）。API Gateway 的 Lambda Authorizer 负责 token 的验证与基本策略生成，但实际的业务级权限校验在后端路由/服务中完成（通过检查看 `request.state.claims['role']`）。若期望在 Gateway 层实现更细粒度的访问控制，建议把 Authorizer 生成的 policy 与角色信息结合，避免使用通配符资源策略。

替换文本（英文）：
RBAC implementation: Role-based access control is enforced at the application level using the token's `role` claim. The API Gateway Lambda Authorizer is responsible for token verification and basic policy generation, but business-level authorization checks are performed within backend routes/services (e.g. by inspecting `request.state.claims['role']`). If fine-grained Gateway-level authorization is required, design the Authorizer policy to reflect role/path/method restrictions rather than using wildcard resources.

---

位置：Appendix → IAM Policy Examples

替换文本（中文）：
在附录中加入下列示例 IAM policy 片段（替换占位符为实际 ARN）：
- Authorizer Lambda（读取 SecretsManager 的示例权限）：
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:<REGION>:<ACCOUNT_ID>:secret:medusa/jwt-*"
    },
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      "Resource": "arn:aws:logs:<REGION>:<ACCOUNT_ID>:log-group:/aws/lambda/<AUTHORIZER_NAME>:*"
    }
  ]
}
```

- ProcessSensorData Lambda（写入 DynamoDB 与 S3）：
```
{ "Version":"2012-10-17", "Statement":[ {"Effect":"Allow","Action":["dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:BatchWriteItem"],"Resource":"arn:aws:dynamodb:<REGION>:<ACCOUNT_ID>:table/medusa-tremor-analysis"},{"Effect":"Allow","Action":["s3:PutObject","s3:GetObject"],"Resource":"arn:aws:s3:::<BUCKET>/raw-data/*"} ] }
```

- API Lambda（查询 DynamoDB）：
```
{ "Version":"2012-10-17", "Statement":[ {"Effect":"Allow","Action":["dynamodb:GetItem","dynamodb:Query","dynamodb:Scan"],"Resource":"arn:aws:dynamodb:<REGION>:<ACCOUNT_ID>:table/medusa-tremor-analysis"} ] }
```

替换文本（英文）：
Include the following sample IAM policy snippets in the Appendix (replace placeholders with actual ARNs):
[Authorizer read SecretsManager example] ... (same JSON as above)

---

位置：Methods → Secrets Management（若论文未说明密钥注入方式）

替换文本（中文）：
密钥管理与部署：在生产环境中，`JWT_SECRET` 通过 AWS Secrets Manager 注入到 Lambda（示例见 `template.yaml`）。本地开发脚本（`start_local.ps1`）包含明显的 dev fallback 值（`dev-secret-key-please-change-in-production`）仅供开发使用。论文应强调切勿在生产使用默认值，并简要说明密钥轮换与访问审计实践。

替换文本（英文）：
Secrets management and deployment: In production, `JWT_SECRET` is injected into Lambda from AWS Secrets Manager (see `template.yaml`). The local startup script (`start_local.ps1`) sets a clearly labeled dev fallback (`dev-secret-key-please-change-in-production`) for local testing only. The manuscript should emphasize that this fallback must never be used in production, and briefly describe key rotation and access auditing practices.

---

位置：Appendix → Reproducibility Commands（添加可执行复现命令）

替换文本（中文，命令示例）：
本地复现示例（PowerShell）：
```
# 设置本地测试环境变量
$env:JWT_SECRET = "dev-secret-key-please-change-in-production"
$env:JWT_EXPIRE_SECONDS = "3600"
$env:REFRESH_TTL_SECONDS = "604800"

# 启动本地后端
cd medusa-cloud-components-python-backend\medusa-cloud-components-python-backend\backend-py
.\start_local.ps1

# 回到仓库根目录并运行设备注册脚本
cd D:\25fall\Capstone\ble\MeDUSA
python register_device.py

# 运行时间戳诊断
python tools\check_timestamps.py
```

替换文本（英文，commands example）：
Local reproduction example (PowerShell):
```
$env:JWT_SECRET = "dev-secret-key-please-change-in-production"
$env:JWT_EXPIRE_SECONDS = "3600"
$env:REFRESH_TTL_SECONDS = "604800"
cd medusa-cloud-components-python-backend\medusa-cloud-components-python-backend\backend-py
.\start_local.ps1
cd D:\25fall\Capstone\ble\MeDUSA
python register_device.py
python tools\check_timestamps.py
```

---

位置：Results / Experiments → 建议新增的实验（可选）

替换文本（中文）：
建议添加：端到端延迟测量（device → ingestion → processing → API → client），时间戳稳健性比较表（修复前后 `tools/check_timestamps.py` 输出对比），以及安全实验（密钥轮换与 token 否认的响应与日志片段）。这些实验的脚本与说明可作为补充材料附带提交。

替换文本（英文）：
Recommended additions: end-to-end latency measurements (device → ingestion → processing → API → client), timestamp-robustness comparison tables (pre/post fixes using `tools/check_timestamps.py`), and security experiments demonstrating key rotation and token revocation responses with CloudWatch logs. Provide scripts and instructions as supplementary material.

---

注意事项：
- 替换时务必保留论文原有数据/图表的参考结果或用真实运行输出替换示例占位值；不要直接使用占位统计作为结论依据。
- 若希望我把这些替换直接写入 PDF（自动化修改），我可以尝试通过生成一个带标注的替换清单（含页码/行号定位），但需要你授权我打开并解析 PDF 来定位文本（我可以继续做此项）。

如果你现在确认“请把这些替换应用到论文”，请选择：
1) 我仅生成上面的替换清单（已完成），并导出为 `docs/paper_replacements.md`（已创建）；
2) 我打开并定位你上传的 PDF，然后给出每处替换的页码/上下文字（可直接用于在编辑器中替换）；
3) 我尝试直接生成一个新的 PDF（或带注释的 PDF）把替换文本写入——注意：这一步需要额外时间并可能改变 PDF 的格式。

请选择 1/2/3 或告诉我你要我现在做哪一步，我会继续执行。
