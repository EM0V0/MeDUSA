# MeDUSA Python Backend (Single Lambda)

This is a **drop-in Python replacement** for Rust Lambda, keeping the same AWS layout:
API Gateway → Lambda (this code) → DynamoDB/S3/WAF/CORS.

## Quick Start (Local)
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
export USE_MEMORY=true JWT_SECRET=dev REFRESH_TTL_SECONDS=604800 JWT_EXPIRE_SECONDS=3600
uvicorn main:app --reload --port 8080
# open http://127.0.0.1:8080/docs
```

## Deploy to Lambda (Zip)
> Build on Linux or use `sam build` to avoid native-wheel issues (bcrypt).
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt -t ./python
zip -r9 backend.zip main.py auth.py models.py db.py storage.py
zip -r9 backend.zip python
aws lambda update-function-code --function-name <YourFunctionName> --zip-file fileb://backend.zip
# Set handler to: main.handler ; Runtime: python3.12
```

## Environment Variables
- `JWT_SECRET`
- `JWT_EXPIRE_SECONDS` (default 3600)
- `REFRESH_TTL_SECONDS` (default 604800)
- `DDB_TABLE_USERS`, `DDB_TABLE_REFRESH`, `DDB_TABLE_POSES`, `DDB_TABLE_REPORTS`
- `S3_BUCKET`, `S3_PREFIX_POSES` (default `poses/`), `S3_PREFIX_REPORTS` (default `reports/`)

## Routes
- `GET /api/v1/admin/health`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET  /api/v1/me`
- `POST /api/v1/files/presign`
- `GET  /api/v1/files/{fileKey:path}`
- `GET  /api/v1/poses?patientId=<id>`
- `POST /api/v1/poses`
- `GET  /api/v1/patients/{userId}/poses`
```

## Notes
- Keep API Gateway integration as **Lambda proxy** and simply switch the function runtime/integration.
- For multiple Lambdas later, extract common code into a **Lambda Layer**.
- This repo intentionally leaves `pose_get` as TODO — wire it to exact DDB schema.
```

