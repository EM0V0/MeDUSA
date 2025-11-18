#!/bin/bash
# Deployment script for MeDUSA Lambda functions
# Usage: ./deploy.sh [function_name]

set -e

FUNCTION_NAME=${1:-medusa-process-sensor-data}
REGION=${AWS_REGION:-us-east-1}
ROLE_ARN=${LAMBDA_ROLE_ARN}

echo "========================================="
echo "MeDUSA Lambda Deployment Script"
echo "========================================="
echo "Function: $FUNCTION_NAME"
echo "Region:   $REGION"
echo ""

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ Error: AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi

# Check if IAM role is set
if [ -z "$ROLE_ARN" ]; then
    echo "⚠ Warning: LAMBDA_ROLE_ARN not set"
    echo "Please set it or create a role with DynamoDB permissions:"
    echo "export LAMBDA_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/medusa-lambda-role"
    exit 1
fi

echo "Step 1: Creating deployment package..."
rm -rf package process_sensor_data.zip
mkdir -p package

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt -t package/ --quiet

# Copy Lambda function
cp process_sensor_data.py package/

# Create ZIP
cd package
zip -r ../process_sensor_data.zip . -q
cd ..
echo "✓ Deployment package created: process_sensor_data.zip"

# Check if function exists
echo ""
echo "Step 2: Checking if Lambda function exists..."
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &>/dev/null; then
    echo "✓ Function exists, updating code..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://process_sensor_data.zip \
        --region $REGION \
        --output json > /dev/null
    echo "✓ Function code updated"
else
    echo "Function does not exist, creating new function..."
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime python3.11 \
        --role $ROLE_ARN \
        --handler process_sensor_data.lambda_handler \
        --zip-file fileb://process_sensor_data.zip \
        --timeout 60 \
        --memory-size 512 \
        --region $REGION \
        --output json > /dev/null
    echo "✓ Function created"
fi

# Update configuration
echo ""
echo "Step 3: Updating function configuration..."
aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --timeout 60 \
    --memory-size 512 \
    --region $REGION \
    --output json > /dev/null
echo "✓ Configuration updated"

# Test function
echo ""
echo "Step 4: Testing function..."
cat > test_event.json <<EOF
{
  "device_id": "test_device_001",
  "patient_id": "test_patient_123",
  "window_size": 100,
  "sampling_rate": 100
}
EOF

echo "Test event:"
cat test_event.json
echo ""

aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload file://test_event.json \
    --region $REGION \
    response.json > /dev/null 2>&1 || true

if [ -f response.json ]; then
    echo "Lambda response:"
    cat response.json | python -m json.tool 2>/dev/null || cat response.json
    echo ""
fi

# Cleanup
rm -f test_event.json response.json

echo ""
echo "========================================="
echo "✅ Deployment Complete!"
echo "========================================="
echo "Function ARN:"
aws lambda get-function --function-name $FUNCTION_NAME --region $REGION --query 'Configuration.FunctionArn' --output text
echo ""
echo "Next steps:"
echo "1. Create DynamoDB table: medusa-tremor-analysis"
echo "2. Grant Lambda permissions to read medusa-sensor-data"
echo "3. Set up EventBridge trigger for periodic processing"
echo ""
