Write-Host "🚀 TESTE RÁPIDO COM AWS CLI..." -ForegroundColor Green

# Configurar endpoint
$endpoint = "--endpoint-url=http://localhost:4566"

# 1. Criar arquivo de teste
Write-Host "📝 Criando arquivo de teste..." -ForegroundColor Yellow
"Este é um arquivo de teste para o pipeline" | Out-File -FilePath test-file.txt -Encoding UTF8

# 2. Criar buckets se não existirem
Write-Host "🪣 Criando buckets S3..." -ForegroundColor Yellow
aws $endpoint s3 mb s3://ingestor-raw 2>$null
aws $endpoint s3 mb s3://ingestor-processed 2>$null

# 3. Criar tabela DynamoDB se não existir
Write-Host "🗃️ Criando tabela DynamoDB..." -ForegroundColor Yellow
aws $endpoint dynamodb create-table --table-name files --attribute-definitions AttributeName=pk,AttributeType=S --key-schema AttributeName=pk,KeyType=HASH --billing-mode PAY_PER_REQUEST 2>$null

# 4. Upload para S3
Write-Host "📤 Fazendo upload para S3..." -ForegroundColor Yellow
aws $endpoint s3 cp test-file.txt s3://ingestor-raw/

Write-Host "⏳ Aguardando processamento..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# 5. Verificar buckets
Write-Host "🔍 Verificando buckets..." -ForegroundColor Yellow
Write-Host "Bucket raw:" -ForegroundColor Cyan
aws $endpoint s3 ls s3://ingestor-raw/ --recursive

Write-Host "Bucket processed:" -ForegroundColor Cyan
aws $endpoint s3 ls s3://ingestor-processed/ --recursive

# 6. Verificar DynamoDB
Write-Host "📊 Verificando DynamoDB..." -ForegroundColor Yellow
aws $endpoint dynamodb scan --table-nam.\scripts\test-pipeline-fix.ps1e files

Write-Host "✅ TESTE CONCLUÍDO!" -ForegroundColor Green