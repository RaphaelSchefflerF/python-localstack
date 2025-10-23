import json
import boto3
import hashlib
from datetime import datetime
import urllib.parse

s3 = boto3.client('s3', endpoint_url='http://localhost:4566')
dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566')
table = dynamodb.Table('files')

def calculate_sha256(bucket, key):
    """Calculate SHA256 checksum of S3 object"""
    response = s3.get_object(Bucket=bucket, Key=key)
    file_content = response['Body'].read()
    return hashlib.sha256(file_content).hexdigest()

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))
    
    try:
        # Extract S3 event details
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')
        
        # Get object metadata
        response = s3.head_object(Bucket=bucket, Key=key)
        size = response['ContentLength']
        etag = response['ETag'].strip('"')
        content_type = response.get('ContentType', 'unknown')
        
        # Calculate SHA256 checksum
        checksum = calculate_sha256(bucket, key)
        
        # Create item for DynamoDB
        item = {
            'pk': f"file#{key}",
            'bucket': bucket,
            'key': key,
            'size': size,
            'etag': etag,
            'contentType': content_type,
            'checksum': checksum,
            'status': 'RAW',
            'createdAt': datetime.utcnow().isoformat()
        }
        
        # Save to DynamoDB
        table.put_item(Item=item)
        print(f"Saved item to DynamoDB: {item['pk']}")
        
        # Copy file to processed bucket
        processed_key = f"processed/{key}"
        copy_source = {'Bucket': bucket, 'Key': key}
        s3.copy_object(
            CopySource=copy_source,
            Bucket='ingestor-processed',
            Key=processed_key
        )
        
        # Delete original file
        s3.delete_object(Bucket=bucket, Key=key)
        
        # Update DynamoDB item
        table.update_item(
            Key={'pk': item['pk']},
            UpdateExpression='SET #status = :status, processedAt = :processedAt, processedKey = :processedKey',
            ExpressionAttributeNames={
                '#status': 'status'
            },
            ExpressionAttributeValues={
                ':status': 'PROCESSED',
                ':processedAt': datetime.utcnow().isoformat(),
                ':processedKey': processed_key
            }
        )
        
        print(f"File processed successfully: {key} -> {processed_key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File processed successfully',
                'original_key': key,
                'processed_key': processed_key
            })
        }
        
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }