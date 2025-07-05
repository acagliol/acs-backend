# SQS Queues Documentation

## Overview

The ACS infrastructure uses Amazon SQS (Simple Queue Service) for asynchronous message processing, particularly for email processing workflows. The system implements a robust queue architecture with dead letter queues for error handling and retry mechanisms.

## Queue Configuration

### Common Settings
- **Queue Type**: Standard Queue (at-least-once delivery)
- **Visibility Timeout**: 300 seconds (5 minutes)
- **Message Retention**: 14 days
- **Dead Letter Queue**: Enabled with 3 retry attempts
- **Removal Policy**: RETAIN (data preserved during deployments)

## Queue Details

### 1. Email Process Queue
- **Queue Name**: `acsd2p-{stage}-EmailProcessQueue`
- **Purpose**: Primary queue for processing incoming emails
- **Message Format**: SES email notifications
- **Processing**: Lambda function triggered by SQS events

#### Configuration
```typescript
{
  queueName: 'acsd2p-{stage}-EmailProcessQueue',
  visibilityTimeout: cdk.Duration.seconds(300),
  retentionPeriod: cdk.Duration.days(14),
  deadLetterQueue: {
    queue: new sqs.Queue(this, 'EmailProcessDLQ', {
      queueName: 'acsd2p-{stage}-EmailProcessDLQ',
      retentionPeriod: cdk.Duration.days(14),
    }),
    maxReceiveCount: 3,
  },
}
```

#### Message Structure
```json
{
  "Records": [
    {
      "messageId": "19dd0b57-b21e-4ac1-bd88-01bbb068cb78",
      "receiptHandle": "MessageReceiptHandle",
      "body": "{\"Type\":\"Notification\",\"MessageId\":\"...\",\"TopicArn\":\"...\",\"Message\":\"...\",\"Timestamp\":\"...\",\"SignatureVersion\":\"1\",\"Signature\":\"...\",\"SigningCertURL\":\"...\"}",
      "attributes": {
        "ApproximateReceiveCount": "1",
        "SentTimestamp": "1523232000000",
        "SenderId": "123456789012",
        "ApproximateFirstReceiveTimestamp": "1523232000001"
      },
      "messageAttributes": {},
      "md5OfBody": "7b270e59b47ff90a553787216d55d91d",
      "eventSource": "aws:sqs",
      "eventSourceARN": "arn:aws:sqs:us-west-1:123456789012:acsd2p-dev-EmailProcessQueue",
      "awsRegion": "us-west-1"
    }
  ]
}
```

#### SES Message Format
```json
{
  "Type": "Notification",
  "MessageId": "uuid",
  "TopicArn": "arn:aws:sns:us-west-1:123456789012:acsd2p-dev-EmailTopic",
  "Message": "{\"notificationType\":\"Received\",\"mail\":{\"timestamp\":\"2024-01-01T00:00:00.000Z\",\"source\":\"sender@example.com\",\"messageId\":\"uuid\",\"destination\":[\"recipient@example.com\"],\"headersTruncated\":false,\"headers\":[{\"name\":\"From\",\"value\":\"Sender Name <sender@example.com>\"},{\"name\":\"To\",\"value\":\"recipient@example.com\"},{\"name\":\"Subject\",\"value\":\"Email Subject\"}],\"commonHeaders\":{\"from\":[\"sender@example.com\"],\"to\":[\"recipient@example.com\"],\"subject\":\"Email Subject\"},\"size\":1234},\"receipt\":{\"timestamp\":\"2024-01-01T00:00:00.000Z\",\"processingTimeMillis\":123,\"recipients\":[\"recipient@example.com\"],\"spamVerdict\":{\"status\":\"PASS\"},\"virusVerdict\":{\"status\":\"PASS\"},\"spfVerdict\":{\"status\":\"PASS\"},\"dkimVerdict\":{\"status\":\"PASS\"},\"dmarcVerdict\":{\"status\":\"PASS\"},\"action\":{\"type\":\"Lambda\",\"functionArn\":\"arn:aws:lambda:us-west-1:123456789012:function:acsd2p-dev-Process-SQS-Queued-Emails\"}}}",
  "Timestamp": "2024-01-01T00:00:00.000Z",
  "SignatureVersion": "1",
  "Signature": "signature",
  "SigningCertURL": "https://sns.us-west-1.amazonaws.com/SimpleNotificationService-..."
}
```

### 2. Email Process Dead Letter Queue (DLQ)
- **Queue Name**: `acsd2p-{stage}-EmailProcessDLQ`
- **Purpose**: Stores failed email processing messages
- **Retention**: 14 days
- **Manual Processing**: Failed messages can be reprocessed manually

#### Configuration
```typescript
{
  queueName: 'acsd2p-{stage}-EmailProcessDLQ',
  retentionPeriod: cdk.Duration.days(14),
  visibilityTimeout: cdk.Duration.seconds(300),
}
```

#### Failed Message Structure
```json
{
  "messageId": "failed-message-id",
  "receiptHandle": "failed-receipt-handle",
  "body": "Original message body",
  "attributes": {
    "ApproximateReceiveCount": "4",
    "SentTimestamp": "1523232000000",
    "SenderId": "123456789012",
    "ApproximateFirstReceiveTimestamp": "1523232000001"
  },
  "messageAttributes": {
    "ErrorCode": {
      "stringValue": "ProcessingError",
      "dataType": "String"
    },
    "ErrorMessage": {
      "stringValue": "Failed to process email content",
      "dataType": "String"
    },
    "FailureCount": {
      "stringValue": "3",
      "dataType": "Number"
    }
  }
}
```

## Message Processing Workflow

### 1. Email Reception
1. **SES Receives Email**: Email arrives at SES
2. **SES Notification**: SES sends notification to SNS topic
3. **SNS to SQS**: SNS forwards message to SQS queue
4. **Lambda Trigger**: SQS event triggers Lambda function

### 2. Message Processing
1. **Message Retrieval**: Lambda function retrieves message from queue
2. **Email Parsing**: Parse email content and metadata
3. **Spam Detection**: Check for spam indicators
4. **Conversation Threading**: Link to existing conversations
5. **Database Storage**: Store email data in DynamoDB
6. **AI Processing**: Generate AI responses if enabled
7. **Email Scheduling**: Schedule follow-up emails if needed

### 3. Error Handling
1. **Processing Failure**: If processing fails, message returns to queue
2. **Retry Logic**: Message retried up to 3 times
3. **Dead Letter Queue**: After 3 failures, message moved to DLQ
4. **Manual Review**: Failed messages can be reviewed and reprocessed

## Integration Points

### SES Integration
- **Email Reception**: SES receives emails and forwards to SNS
- **SNS Topic**: SNS topic forwards messages to SQS queue
- **Lambda Processing**: SQS triggers Lambda function for processing

### Lambda Integration
- **Event Source**: SQS events trigger Lambda functions
- **Batch Processing**: Lambda can process multiple messages
- **Error Handling**: Lambda handles processing errors and retries

### DynamoDB Integration
- **Data Storage**: Processed email data stored in DynamoDB
- **Conversation Tracking**: Email threading and conversation management
- **User Data**: User preferences and settings

## Monitoring and Alerting

### CloudWatch Metrics
- **NumberOfMessagesSent**: Messages sent to queue
- **NumberOfMessagesReceived**: Messages received from queue
- **NumberOfMessagesDeleted**: Messages successfully processed
- **ApproximateNumberOfMessagesVisible**: Messages waiting for processing
- **ApproximateNumberOfMessagesNotVisible**: Messages being processed
- **ApproximateNumberOfMessagesDelayed**: Delayed messages
- **SentMessageSize**: Size of sent messages
- **ReceiveMessageWaitTimeSeconds**: Time waiting for messages

### CloudWatch Alarms
- **High Queue Depth**: Alert when queue has many unprocessed messages
- **High Error Rate**: Alert when many messages fail processing
- **Processing Latency**: Alert when message processing takes too long
- **DLQ Depth**: Alert when dead letter queue has messages

### Logging
- **SQS Access Logs**: All SQS API calls logged via CloudTrail
- **Lambda Execution Logs**: Processing details logged to CloudWatch
- **Error Logs**: Failed processing attempts logged with details

## Performance Optimization

### Queue Configuration
- **Visibility Timeout**: Set based on processing time (300 seconds)
- **Message Retention**: 14 days for message recovery
- **Batch Processing**: Process multiple messages per Lambda invocation
- **Concurrent Processing**: Multiple Lambda instances can process simultaneously

### Processing Optimization
- **Efficient Parsing**: Optimize email parsing for speed
- **Database Batching**: Batch database operations
- **Caching**: Cache frequently accessed data
- **Parallel Processing**: Process multiple aspects of email simultaneously

## Error Handling and Recovery

### Retry Strategy
- **Automatic Retries**: Failed messages automatically retried
- **Exponential Backoff**: Increasing delays between retries
- **Max Retries**: 3 attempts before moving to DLQ
- **Error Classification**: Different error types handled differently

### Dead Letter Queue Management
- **Manual Review**: Failed messages reviewed manually
- **Error Analysis**: Analyze failure patterns and root causes
- **Reprocessing**: Manually reprocess failed messages
- **Cleanup**: Remove successfully reprocessed messages

### Recovery Procedures
1. **Queue Monitoring**: Monitor queue depth and processing rates
2. **Error Investigation**: Investigate processing failures
3. **System Recovery**: Restore system functionality
4. **Message Reprocessing**: Reprocess failed messages from DLQ

## Security Configuration

### Access Control
- **IAM Policies**: Role-based access control for queue operations
- **Resource Policies**: Queue-level permissions
- **Cross-Account Access**: Configurable through policies
- **Encryption**: Messages encrypted in transit and at rest

### Message Security
- **Message Encryption**: Messages encrypted using AWS managed keys
- **Access Logging**: All access attempts logged
- **Audit Trail**: Complete audit trail for compliance
- **Data Protection**: Sensitive data handled securely

## Cost Optimization

### Pricing Model
- **Pay per Request**: Charges for API requests
- **Data Transfer**: Charges for data transfer out of AWS
- **Message Storage**: Charges for message storage time
- **Dead Letter Queue**: Additional charges for DLQ storage

### Cost Monitoring
- **CloudWatch Cost Explorer**: Track SQS costs
- **Usage Metrics**: Monitor message volume and processing
- **Cost Alerts**: Set up alerts for cost thresholds
- **Optimization**: Optimize message processing for cost efficiency

### Optimization Strategies
- **Batch Processing**: Process multiple messages per request
- **Efficient Processing**: Minimize processing time
- **Message Cleanup**: Remove processed messages promptly
- **DLQ Management**: Regularly clean up dead letter queue

## Best Practices

### Queue Design
- **Single Purpose**: Each queue has a specific purpose
- **Message Size**: Keep messages under 256KB
- **Processing Time**: Design for processing within visibility timeout
- **Error Handling**: Implement comprehensive error handling

### Message Processing
- **Idempotency**: Ensure processing is idempotent
- **Error Recovery**: Implement proper error recovery mechanisms
- **Monitoring**: Monitor processing performance and errors
- **Testing**: Test processing logic thoroughly

### Security Best Practices
- **Least Privilege**: Grant minimum required permissions
- **Encryption**: Always encrypt sensitive messages
- **Access Logging**: Enable access logging
- **Regular Audits**: Conduct regular security audits

### Performance Best Practices
- **Batch Operations**: Use batch operations when possible
- **Concurrent Processing**: Process messages concurrently
- **Monitoring**: Monitor performance metrics
- **Optimization**: Continuously optimize processing

## Troubleshooting

### Common Issues

#### High Queue Depth
- **Symptoms**: Many messages waiting for processing
- **Causes**: Processing bottlenecks, Lambda throttling
- **Solutions**: Scale Lambda functions, optimize processing

#### High Error Rate
- **Symptoms**: Many messages in dead letter queue
- **Causes**: Processing errors, invalid message format
- **Solutions**: Fix processing logic, validate message format

#### Processing Latency
- **Symptoms**: Messages taking long time to process
- **Causes**: Lambda cold starts, inefficient processing
- **Solutions**: Optimize Lambda functions, use provisioned concurrency

#### Message Loss
- **Symptoms**: Messages not processed
- **Causes**: Lambda failures, visibility timeout issues
- **Solutions**: Check Lambda logs, adjust visibility timeout

### Debugging Tools
- **CloudWatch Logs**: Lambda execution logs
- **SQS Console**: Queue metrics and message details
- **CloudTrail**: API call logs
- **X-Ray**: Distributed tracing for complex workflows 