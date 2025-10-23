Write-Host "Tearing down resources..." -ForegroundColor Yellow

# Delete S3 buckets
try {
    Write-Host "Deleting S3 buckets..."
    awslocal s3 rb s3://ingestor-raw --force 2>$null
    awslocal s3 rb s3://ingestor-processed --force 2>$null
} catch {
    Write-Host "Error deleting S3 buckets: $_" -ForegroundColor Red
}

# Delete DynamoDB table
try {
    Write-Host "Deleting DynamoDB table..."
    awslocal dynamodb delete-table --table-name files 2>$null
} catch {
    Write-Host "Error deleting DynamoDB table: $_" -ForegroundColor Red
}

# Delete Lambda functions
try {
    Write-Host "Deleting Lambda functions..."
    awslocal lambda delete-function --function-name ingest-file 2>$null
    awslocal lambda delete-function --function-name files-api 2>$null
} catch {
    Write-Host "Error deleting Lambda functions: $_" -ForegroundColor Red
}

# Delete IAM role
try {
    Write-Host "Deleting IAM role..."
    awslocal iam delete-role-policy --role-name lambda-execution-role --policy-name s3-dynamodb-access 2>$null
    awslocal iam delete-role --role-name lambda-execution-role 2>$null
} catch {
    Write-Host "Error deleting IAM role: $_" -ForegroundColor Red
}

Write-Host "All resources deleted!" -ForegroundColor Green