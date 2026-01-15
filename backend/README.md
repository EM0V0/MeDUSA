# MeDUSA Cloud Backend

This directory contains the serverless backend infrastructure for the MeDUSA system, built using **AWS Serverless Application Model (SAM)** and **Python**.

## 📂 Project Structure

- **`backend-py/`**: The core Python application logic (Lambda function source code).
- **`template.yaml`**: AWS SAM template defining the infrastructure (Lambda, API Gateway, DynamoDB).
- **`configure-ses.ps1`**: Helper script to configure AWS SES for email verification.
- **`test_device_api.ps1`**: PowerShell script for testing Device Management APIs.

## 🚀 Deployment

### Prerequisites
- AWS CLI configured
- AWS SAM CLI installed
- Python 3.10+

### Deploy with SAM
```bash
# Build the application
sam build

# Deploy to AWS
sam deploy --guided
```

## 🧪 Testing

### API Testing
Use the provided PowerShell script to verify the API endpoints:
```powershell
./test_device_api.ps1
```

### Local Development
Refer to **[backend-py/README.md](backend-py/README.md)** for detailed instructions on running the Python code locally using `uvicorn`.

## 📧 Email Configuration
Run the configuration wizard to set up sender identity for email notifications:
```powershell
./configure-ses.ps1
```
