# MeDUSA 应用测试报告（标准版）

## 1. 测试范围（Scope）
本报告涵盖 MeDUSA App（Flutter 客户端）以及与其交互的 API 功能相关测试项，包括：

- 应用静态分析（CT24）
- 配置文件安全测试（CT28）
- 网络与 TLS 安全性测试（CT37、CT38）
- 抗压性 / 稳定性测试（CT39）
- 网络栈漏洞扫描（CT40）
- HTTP 安全 Header 测试（CT43）
- 用户认证与会话安全测试（CT46、CT49、CT51、CT53）
- 输入验证与异常处理（CT47、CT100、CT102）
- API Token 生命周期验证（CT101）
- 恶意代码扫描（CT127）

## 2. 测试环境（Environment）
【硬件环境】
- Windows / macOS / Linux 均可用于测试
- 测试设备：Android/iOS 设备或模拟器

【软件工具】
- MobSF
- VS Code
- nmap
- testssl.sh
- Baton
- Nessus
- OWASP ZAP
- Burp Suite
- Postman
- ClamAV

【网络环境】
- 需可访问 MeDUSA API 域名
- 测试环境具备 HTTPS 支持

## 3. 测试方法（Methodology）
测试方法包括：

- 静态分析（Static Analysis）
- 动态分析（Dynamic Analysis）
- 黑盒安全测试（Blackbox Testing）
- 灰盒 API 测试（Greybox Testing）
- 网络扫描（Network Scanning）
- 配置审查（Configuration Review）
- 风险驱动测试（Risk-Based Testing）

## CT24 — 应用静态分析（MobSF）
【目的】
识别代码层安全弱点，如权限配置、硬编码信息、不安全函数等。

【步骤】
1. 使用 Docker 启动 MobSF：
   docker pull opensec/mobile-security-framework-mobsf
2. 上传 APK 或源码生成报告。
3. 检查以下模块：
   - Manifest 权限
   - 网络安全配置
   - WebView 配置
   - 硬编码字符串

【Pass】
无中高危风险。

【Fail】
发现敏感信息或危险配置。

## CT28 — 配置密钥硬编码检查
【目的】
确保未在代码中硬编码敏感信息。

【步骤】
1. 使用 MobSF 查看 Hardcoded Secrets。
2. VS Code 搜索 password、token、secret 等。
3. 核实结果。

【Pass】
无真实敏感 Hardcode。

【Fail】
发现敏感 Key。

## CT37 — 公网端口暴露检查
【目的】
确认后端未暴露非预期端口。

【步骤】
nmap -Pn -sV <domain>

【Pass】
仅暴露 443/HTTPS。

【Fail】
发现额外端口。

## CT38 — TLS 配置测试
【目的】
确认仅启用安全的 TLS 协议与 Cipher。

【步骤】
./testssl.sh <domain>

【Pass】
仅 TLS1.2/1.3 + 强加密。

【Fail】
启用了弱 Cipher 或旧协议。

## CT39 — 抗压性测试（DoS）
【目的】
确认高流量下服务可用。

【步骤】
baton -u https://domain

【Pass】
无崩溃，无显著延迟。

【Fail】
出现服务不可用情况。

## CT40 — 网络栈漏洞扫描（Nessus）
【目的】
识别后端环境中的已知安全漏洞。

【Pass】
无高危漏洞。

## CT43 — HTTP Header 安全性测试
【目的】
确认响应中配置了必要安全 Header。

【检查项】
- CSP
- X-Frame-Options
- HSTS

【Pass】
全部正确配置。

## CT46 — 账户锁定机制测试
【目的】
防止暴力破解。

【Pass】
连续错误登录后账号被锁定。

## CT47 — 输入长度测试
【目的】
确认对超长输入有安全处理。

【Pass】
无信息泄漏、无异常堆栈输出。

## CT49 — 登出后 Token 是否失效
【Pass】
登出后旧 Token 不可再次使用。

## CT51 — MFA 功能检查
【Pass】
应用提供 MFA 机制。

## CT52 — RBAC 权限检查
【Pass】
低权限用户无法访问高权限 API。

## CT53 — 密码策略检查
【Pass】
弱密码被系统拒绝。

## CT93 — HTTP 跳转 HTTPS 测试
【Pass】
HTTP 请求均跳转至 HTTPS。

## CT100 — 注入漏洞测试
【Pass】
无 SQLi/XSS/异常堆栈泄漏。

## CT101 — Token 过期测试
【Pass】
Token 到期后不可继续使用。

## CT102 — API 大输入测试
【Pass】
系统安全处理超长输入。

## CT127 — 恶意代码扫描（ClamAV）
【Pass】
未发现恶意签名。
