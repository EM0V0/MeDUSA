说明：下面给出可直接替换到论文或技术文档中的段落（中文），并附写作补充建议与参考位置。

1) 摘要/方法中“认证”小节（替换段落，中文）

建议替换：

“认证与会话管理：本系统使用基于 JSON Web Token (JWT) 的访问控制。服务器端使用 PyJWT 来签发与验证令牌，密码采用 Argon2id 哈希存储以提高抗离线暴力破解能力。访问令牌使用对称签名算法 HS256 签名，签名密钥通过环境变量 `JWT_SECRET` 提供；在生产环境中，该密钥从 AWS Secrets Manager 注入并应进行周期性轮换，开发环境可使用明显标注的 dev fallback 值以便本地调试。系统同时发放刷新令牌以延长会话，且对访问令牌实行较短有效期（参见实现：`medusa-cloud-components-python-backend/backend-py/auth.py`）。"

2) 方法/实现细节 — Authorizer（替换或新增段落）

建议替换/新增：

“我们在 API Gateway 之前部署了一个 Lambda Token Authorizer（实现见 `lambda_functions/authorizer.py`）。Authorizer 从事件字段 `authorizationToken` 读取 Bearer token，去除 `Bearer ` 前缀后使用环境变量 `JWT_SECRET` 并以 HS256 验证 JWT。成功验证后返回一个 IAM policy document；当前实现为了简化测试，对 API 使用了通配符资源策略（即较宽松的 `/*/*` 规则），具体的访问控制在应用层通过 token 中的 `role` claim 实现。建议在论文中明确：生产环境应把 `JWT_SECRET` 存放在 Secrets Manager，并在 Authorizer/后端中严格校验 `iss`、`aud` 等字段以减少滥用风险。”

3) 设备注册/引导（替换/澄清）

建议替换：

“仓库包含一个用于快速绑定测试设备的脚本 `register_device.py`，该脚本直接将演示设备记录写入 DynamoDB 表 `medusa-devices-prod`。此脚本用于开发/测试演示，不等同于生产级设备引导流程。生产环境建议使用 AWS IoT 的证书机制或受控注册 API，确保设备具有唯一可验证的身份（例如 X.509 证书）、使用 TLS 通道进行通信，并在服务端执行严格验证与最小权限写入数据库。”

4) 时间戳处理（建议新增/引用）

建议新增段落：

“为保证时序分析的可靠性，后端统一采用 ISO8601 UTC（带尾部`Z`）格式存储时间戳。项目提供诊断脚本（`tools/check_timestamps.py`）用于解析历史数据、计算时间间隔、及检测长间隙（>1.5s）或不规范格式的条目。论文中关于‘时间戳已修复’的论断，建议附上该脚本输出的统计摘要（总样本数、最小/最大/平均间隔、异常间隙计数）以增强可验证性。”

5) 写作与结构建议（短清单）

- 把“设计（Design）”与“实现（Implementation）”分为独立小节，设计部分描述安全模型（RBAC、JWT 生命周期、设备引导策略），实现部分引用关键代码与文件路径。
- 在方法一节加入一张简明数据流图（device → AWS IoT / API → Lambda processing → DynamoDB → API → client），在图注中标注认证点与证书/密钥管理点。
- 附录中提供“复现步骤”（如何本地启动后端、设置 `JWT_SECRET`、运行 `register_device.py`、运行 `tools/check_timestamps.py` 并收集输出），并给出示例输出片段。
- 若论文声称“已部署 RBAC/生产级密钥管理”，请补充：SecretsManager 路径、Token 生命周期参数（`JWT_EXPIRE_SECONDS`、`REFRESH_TTL_SECONDS`）以及 Authorizer 的精确行为（HS256/对称密钥或 RS256/公钥）。

6) 需要在论文中显式修正/检查的语句示例

- 将“使用 bcrypt”改为“使用 Argon2id”。
- 将“JWT 签名与密钥管理未说明”补为“使用 HS256 且密钥通过环境变量注入，生产中建议由 Secrets Manager 进行管理”。

---

参考代码位置（可在论文注脚中引用）：
- `lambda_functions/authorizer.py` — Lambda Token Authorizer 实现
- `medusa-cloud-components-python-backend/backend-py/auth.py` — 发行/验证 JWT、Argon2 密码散列
- `register_device.py` — 演示设备注册脚本（DynamoDB）
- `tools/check_timestamps.py` — 时间戳诊断脚本

如果你需要，我可以把这些段落翻译成英文并按论文目标期刊的学术写作风格润色。