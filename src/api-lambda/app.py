import json
import boto3
from boto3.dynamodb.conditions import Key, Attr
from datetime import datetime

dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566')
table = dynamodb.Table('files')

def lambda_handler(event, context):
    print("API Event:", json.dumps(event))
    
    http_method = event.get('httpMethod')
    path = event.get('path')
    path_parameters = event.get('pathParameters', {})
    query_params = event.get('queryStringParameters', {})
    
    try:
        if http_method == 'GET' and path == '/files':
            return get_files(query_params)
        elif http_method == 'GET' and path_parameters and 'id' in path_parameters:
            return get_file_by_id(path_parameters['id'])
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Not found'})
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def get_files(query_params):
    """Get paginated list of files with optional filters"""
    
    # Build filter expression
    filter_expr = None
    expr_attr_names = {}
    expr_attr_values = {}
    
    status = query_params.get('status')
    if status:
        filter_expr = Attr('status').eq(status)
    
    # Process date filters
    from_date = query_params.get('from')
    to_date = query_params.get('to')
    
    if from_date and to_date:
        date_filter = Attr('processedAt').between(from_date, to_date)
        filter_expr = date_filter if not filter_expr else filter_expr & date_filter
    elif from_date:
        date_filter = Attr('processedAt').gte(from_date)
        filter_expr = date_filter if not filter_expr else filter_expr & date_filter
    elif to_date:
        date_filter = Attr('processedAt').lte(to_date)
        filter_expr = date_filter if not filter_expr else filter_expr & date_filter
    
    # Scan with filter
    if filter_expr:
        response = table.scan(
            FilterExpression=filter_expr,
            Limit=100
        )
    else:
        response = table.scan(Limit=100)
    
    items = response.get('Items', [])
    
    # Sort by processedAt descending
    items.sort(key=lambda x: x.get('processedAt', ''), reverse=True)
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'files': items,
            'count': len(items)
        })
    }

def get_file_by_id(file_id):
    """Get single file by ID"""
    
    # Ensure proper format
    if not file_id.startswith('file#'):
        file_id = f"file#{file_id}"
    
    response = table.get_item(Key={'pk': file_id})
    
    if 'Item' not in response:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'File not found'})
        }
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(response['Item'])
    }