#!/bin/bash

# Criar buckets S3 necessários
echo "Criando buckets S3..."
awslocal s3 mb s3://ingestor-raw || echo "Bucket ingestor-raw já existe."
awslocal s3 mb s3://ingestor-processed || echo "Bucket ingestor-processed já existe."

# Create S3 buckets
echo "Creating S3 buckets..."
awslocal s3 mb s3://ingestor-raw
awslocal s3 mb s3://ingestor-processed

# Create DynamoDB table
echo "Creating DynamoDB table..."
awslocal dynamodb create-table \
    --table-name files \
    --attribute-definitions \
        AttributeName=pk,AttributeType=S \
    --key-schema \
        AttributeName=pk,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

# Create IAM role for Lambda
echo "Creating IAM role..."
awslocal iam create-role \
    --role-name lambda-execution-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'

# Attach policies to the role
awslocal iam attach-role-policy \
    --role-name lambda-execution-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

awslocal iam put-role-policy \
    --role-name lambda-execution-role \
    --policy-name s3-dynamodb-access \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::ingestor-raw",
                    "arn:aws:s3:::ingestor-raw/*",
                    "arn:aws:s3:::ingestor-processed",
                    "arn:aws:s3:::ingestor-processed/*"
                ]
            },
            {
                "Effect": "Allow",
                "Action": [
                    "dynamodb:PutItem",
                    "dynamodb:GetItem",
                    "dynamodb:UpdateItem",
                    "dynamodb:Query",
                    "dynamodb:Scan"
                ],
                "Resource": "arn:aws:dynamodb:us-east-1:000000000000:table/files"
            }
        ]
    }'

# Wait for role to be available
sleep 5

# Create ingest Lambda function
echo "Creating ingest Lambda function..."
cd /docker-entrypoint-initaws.d/src/ingest-lambda
zip -r /tmp/ingest-lambda.zip .

awslocal lambda create-function \
    --function-name ingest-file \
    --runtime python3.9 \
    --zip-file fileb:///tmp/ingest-lambda.zip \
    --handler app.lambda_handler \
    --role arn:aws:iam::000000000000:role/lambda-execution-role

# Configure S3 trigger for ingest Lambda
echo "Configuring S3 trigger..."
awslocal s3api put-bucket-notification-configuration \
    --bucket ingestor-raw \
    --notification-configuration '{
        "LambdaFunctionConfigurations": [
            {
                "LambdaFunctionArn": "arn:aws:lambda:us-east-1:000000000000:function:ingest-file",
                "Events": ["s3:ObjectCreated:*"]
            }
        ]
    }'

# Create API Lambda function
echo "Creating API Lambda function..."
cd /docker-entrypoint-initaws.d/src/api-lambda
zip -r /tmp/api-lambda.zip .

awslocal lambda create-function \
    --function-name files-api \
    --runtime python3.9 \
    --zip-file fileb:///tmp/api-lambda.zip \
    --handler app.lambda_handler \
    --role arn:aws:iam::000000000000:role/lambda-execution-role

# Create API Gateway
echo "Creating API Gateway..."
awslocal apigateway create-rest-api \
    --name files-api

API_ID=$(awslocal apigateway get-rest-apis --query "items[?name=='files-api'].id" --output text)
PARENT_ID=$(awslocal apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/'].id" --output text)

# Create /files resource
RESOURCE_ID=$(awslocal apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $PARENT_ID \
    --path-part files \
    --query "id" --output text)

# Create /files/{id} resource
ID_RESOURCE_ID=$(awslocal apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $RESOURCE_ID \
    --path-part '{id}' \
    --query "id" --output text)

# Setup methods
awslocal apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --authorization-type NONE

awslocal apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $ID_RESOURCE_ID \
    --http-method GET \
    --authorization-type NONE

# Setup integrations
awslocal apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:files-api/invocations

awslocal apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $ID_RESOURCE_ID \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:files-api/invocations

# Deploy API
awslocal apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name dev

echo "API Gateway URL: http://localhost:4566/restapis/$API_ID/dev/_user_request_/files"

echo "All resources created successfully!"