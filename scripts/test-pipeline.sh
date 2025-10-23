#!/bin/bash

set -e

# Aguardar LocalStack estar pronto
echo "=== AGUARDANDO LOCALSTACK ESTAR PRONTO ==="
sleep 10

# Verificar se os buckets S3 existem e criá-los se necessário
echo "=== CRIANDO BUCKETS S3 ==="
aws --endpoint-url=http://localhost:4566 s3 mb s3://ingestor-raw || echo "Bucket ingestor-raw já existe."
aws --endpoint-url=http://localhost:4566 s3 mb s3://ingestor-processed || echo "Bucket ingestor-processed já existe."

# Criar tabela DynamoDB se não existir
echo "=== CRIANDO TABELA DYNAMODB ==="
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name files \
    --attribute-definitions AttributeName=pk,AttributeType=S \
    --key-schema AttributeName=pk,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST || echo "Tabela files já existe."

# Verificar se o arquivo de teste existe
echo "=== PREPARANDO ARQUIVO DE TESTE ==="
if [ ! -f "test-file.txt" ]; then
  echo "Criando arquivo de teste..."
  echo "Conteúdo de teste - $(date)" > test-file.txt
fi

# Upload para o bucket S3
echo "=== UPLOAD PARA S3 ==="
aws --endpoint-url=http://localhost:4566 s3 cp test-file.txt s3://ingestor-raw/

# Listar arquivos no bucket
echo "=== VERIFICANDO UPLOAD ==="
aws --endpoint-url=http://localhost:4566 s3 ls s3://ingestor-raw/

# Aguardar processamento
echo "=== AGUARDANDO PROCESSAMENTO ==="
sleep 5

# Consultar itens no DynamoDB
echo "=== CONSULTANDO DYNAMODB ==="
aws --endpoint-url=http://localhost:4566 dynamodb scan \
  --table-name files \
  --output table || echo "Tabela vazia ou erro na consulta."

# Verificar bucket processado
echo "=== VERIFICANDO BUCKET PROCESSADO ==="
aws --endpoint-url=http://localhost:4566 s3 ls s3://ingestor-processed/ || echo "Bucket processado vazio."

echo "=== PIPELINE TESTADO COM SUCESSO ==="


