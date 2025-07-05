import json
import base64
import boto3
from boto3.dynamodb.conditions import Key
from common import get_cors_headers
import os
from datetime import datetime, timedelta
from decimal import Decimal

# Use environment variables for region
region = os.environ.get('CDK_AWS_REGION', os.environ.get('AWS_REGION'))
dynamodb = boto3.resource('dynamodb', region_name=region)
table = dynamodb.Table('Conversations')

def handle_get_all_threads(user_id, event):
    try:
        response = table.query(
            IndexName='associated_account-is_first_email-index',
            KeyConditionExpression=Key('associated_account').eq(user_id)
        )

        threads = [
            {
                'id': item['conversation_id'],
                'sender': item['sender'],
                'timestamp': item['timestamp'],
                'is_first': base64.b64encode(item['is_first_email'].value).decode('utf-8')
            }
            for item in response.get('Items', [])
        ]

        return {
            'statusCode': 200,
            'body': json.dumps({'threads': threads, 'user_id': user_id}),
            'headers': get_cors_headers(event)
        }

    except Exception as e:
        print(f"Error retrieving threads: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal Server Error'}),
            'headers': get_cors_headers(event)
        }
