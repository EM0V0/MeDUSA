# MeDUSA 完整测试指南（补全版）

## API 测试（11项）
### CT93 — HTTP → HTTPS 跳转测试
确保所有 HTTP 请求自动跳转至 HTTPS。

### CT94 — 外部访问控制
验证 API 是否限制公网访问不该暴露的端点。

### CT95 — TLS 版本 & Cipher Suite 测试
对 API 域名执行 testssl.sh，确保仅支持 TLS1.2/1.3。

### CT96 — 恶意流量 / 高负载抗性
使用 Baton / ab 对 API 进行压力测试。

### CT100 — 注入攻击测试（SQLi/XSS）
使用 ZAP/Postman 提交攻击载荷，检查异常或回显。

### CT101 — Token 过期机制验证
等待 Token 过期并验证 API 是否阻止访问。

### CT102 — Buffer Overflow 长输入测试
发送超长 JSON 字段，检查是否信息泄露。

### CT103 — 未认证访问控制
验证无 Token 请求是否全部拒绝。

### CT125 — API 依赖库 SCA
使用 safety/grype 扫描 Python/Node 等依赖漏洞。

### CT126 — 源码静态分析（SAST）
使用 SonarQube / Bandit 对 API 源码执行静态分析。

### CT128（部分 API 相关） — 云函数依赖 SCA
检查 serverless function 的依赖库漏洞。

## Cloud Functions（1项）
### CT128 — 云函数软件成分分析（SCA）
扫描 AWS Lambda/OCI Function 的依赖项是否存在 CVE。

## Database Layer（5项）
### CT106 — 数据库端口扫描
使用 nmap 检查数据库实例是否暴露危险端口。

### CT107 — 数据库访问控制
确认只有 API 层可以访问数据库（网络 ACL / VPC）。

### CT109 — 数据库静态加密（Encryption at Rest）
验证 DynamoDB / Oracle 是否启用了加密。

### CT110 — 自动备份机制
检查数据库是否开启周期性备份。

### CT111 — 数据加密（密码、PII）
确认敏感字段采用加密/哈希（如 Argon2）。

## Cloud Storage（1项）
### CT132 — Cloud Storage 公共访问检查
验证 S3/OCI object bucket 是否阻止公共读取。

