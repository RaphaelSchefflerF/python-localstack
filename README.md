# Python LocalStack

Pipeline local para ingestão de arquivos usando LocalStack (S3, DynamoDB, Lambda, API Gateway).

## Arquitetura

1. **Upload** → S3 Bucket (`ingestor-raw`)
2. **Trigger** → Lambda (`ingest-file`) processa metadados
3. **Storage** → DynamoDB (`files`) + S3 Bucket (`ingestor-processed`)
4. **API** → API Gateway + Lambda (`files-api`) para consulta

## Pré-requisitos e Instalação

### 1. Docker e Docker Compose

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io docker-compose-plugin

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

### 2. AWS CLI

```bash
# Ubuntu/Debian
sudo apt install awscli

# Ou via pip
pip install awscli

# Configurar (use credenciais dummy para LocalStack)
aws configure
# AWS Access Key ID: test
# AWS Secret Access Key: test
# Default region name: us-east-1
# Default output format: json
```

### 3. jq (JSON processor)

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

### 4. Python e dependências

```bash
# Instalar Python 3.8+
sudo apt install python3 python3-pip

# Instalar dependências do projeto
pip install boto3 requests
```

## Como executar

### Comando único de subida:

```bash
docker-compose up -d && ./scripts/test-pipeline.sh
```

### Comando para derrubar:

```bash
docker-compose down -v
```

## Comandos para Screenshots/GIFs

### 1. Preparar terminal para captura:

```bash
# Limpar terminal
clear

# Mostrar status inicial
echo "=== INICIANDO PIPELINE ==="
docker-compose ps
```

### 2. Executar pipeline completo:

```bash
# Subir serviços
echo "=== SUBINDO LOCALSTACK ==="
docker-compose up -d

# Aguardar inicialização
echo "=== AGUARDANDO INICIALIZAÇÃO ==="
sleep 15

# Executar testes
echo "=== EXECUTANDO PIPELINE ==="
./scripts/test-pipeline.sh

# Verificar logs
echo "=== LOGS DO LAMBDA ==="
aws --endpoint-url=http://localhost:4566 logs describe-log-groups
```

### 3. Screenshots individuais:

#### Screenshot 1 - Upload para S3:

```bash
echo "=== UPLOAD PARA S3 ==="
aws --endpoint-url=http://localhost:4566 s3 cp test-file.txt s3://ingestor-raw/
aws --endpoint-url=http://localhost:4566 s3 ls s3://ingestor-raw/
```

#### Screenshot 2 - Logs do Lambda:

```bash
echo "=== LOGS DO PROCESSAMENTO ==="
aws --endpoint-url=http://localhost:4566 logs filter-log-events \
  --log-group-name /aws/lambda/ingest-file \
  --start-time $(date -d '1 minute ago' +%s)000
```

#### Screenshot 3 - Item no DynamoDB:

```bash
echo "=== DADOS NO DYNAMODB ==="
aws --endpoint-url=http://localhost:4566 dynamodb scan \
  --table-name files \
  --output table
```

#### Screenshot 4 - API respondendo:

```bash
echo "=== TESTANDO API ==="
API_URL=$(aws --endpoint-url=http://localhost:4566 apigateway get-rest-apis \
  --query 'items[0].id' --output text)
curl -s "http://localhost:4566/restapis/$API_URL/local/_user_request_/files" | jq .
```

## Decisões de Arquitetura

### Por que LocalStack?

- **Desenvolvimento local**: Evita custos da AWS durante desenvolvimento
- **Testes isolados**: Ambiente controlado e reproduzível
- **Rapidez**: Deploy instantâneo vs. minutos na AWS real

### Escolha das tecnologias:

- **S3**: Storage natural para arquivos de entrada e saída
- **Lambda**: Processamento serverless, escalável automaticamente
- **DynamoDB**: NoSQL rápido para metadados de arquivos
- **API Gateway**: Interface REST padronizada

### Estrutura do projeto:

- **docker-compose.yml**: Orquestração simples dos serviços
- **scripts/**: Automação de deploy e testes
- **lambdas/**: Código das funções isolado por responsabilidade

## Resultado do Pipeline (Exemplo de Execução)

```
=== AGUARDANDO LOCALSTACK ESTAR PRONTO ===
=== CRIANDO BUCKETS S3 ===
make_bucket: ingestor-raw
make_bucket: ingestor-processed
=== CRIANDO TABELA DYNAMODB ===
An error occurred (ResourceInUseException) when calling the CreateTable operation: Table already exists: files
Tabela files já existe.
=== PREPARANDO ARQUIVO DE TESTE ===
=== UPLOAD PARA S3 ===
upload: ./test-file.txt to s3://ingestor-raw/test-file.txt
=== VERIFICANDO UPLOAD ===
2025-10-22 22:36:26         19 test-file.txt
=== AGUARDANDO PROCESSAMENTO ===
=== CONSULTANDO DYNAMODB ===
-----------------------------------------------
|                    Scan                     |
+-------------------+--------+----------------+
| ConsumedCapacity  | Count  | ScannedCount   |
+-------------------+--------+----------------+
|  None             |  0     |  0             |
+-------------------+--------+----------------+
=== VERIFICANDO BUCKET PROCESSADO ===
=== PIPELINE TESTADO COM SUCESSO ===
```

> **Nota:** O upload para o S3 foi realizado com sucesso, mas não há itens no DynamoDB nem arquivos processados. Isso indica que a trigger do Lambda ou o processamento do arquivo ainda precisa ser ajustado para completar o fluxo end-to-end.
