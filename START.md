# MeDUSA 快速启动

## 🚀 后端 API（已部署到云端）

**云端 API**: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1`

### 本地测试（可选）

如需在本地运行后端：

```powershell
cd medusa-cloud-components-python-backend\medusa-cloud-components-python-backend\backend-py
.\start_local.ps1
```

访问：`http://localhost:8080/api/v1`

### 更新云端

```powershell
cd medusa-cloud-components-python-backend\medusa-cloud-components-python-backend
.\deploy.ps1
```

---

## 📱 前端应用

### 启动 Flutter 应用

```powershell
cd meddevice-app-flutter-main
flutter pub get
flutter run
```

**前端已配置为自动连接云端 API**

---

## 📝 API 端点

所有端点都使用 `/api/v1` 前缀：

- `GET /api/v1/admin/health` - 健康检查
- `POST /api/v1/auth/register` - 用户注册
- `POST /api/v1/auth/login` - 用户登录
- `GET /api/v1/me` - 获取当前用户
- `POST /api/v1/poses` - 创建姿态数据
- `GET /api/v1/poses?patientId={id}` - 列出姿态数据

详见：`ARCHITECTURE_ANALYSIS.md` 和 `CLOUD_DEPLOYMENT_SUCCESS.md`

