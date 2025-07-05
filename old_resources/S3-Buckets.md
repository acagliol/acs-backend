# S3 Buckets Documentation

## Overview

The ACS infrastructure uses Amazon S3 for file storage, email attachments, and general data persistence. All buckets are configured with versioning, encryption, and retention policies to ensure data security and compliance.

## Bucket Configuration

### Common Settings
- **Versioning**: Enabled for all buckets
- **Encryption**: S3 managed keys <name>
- **Public Access**: Blocked for all buckets
- **Removal Policy**: RETAIN (data preserved during deployments)
- **Auto Delete Objects**: Disabled (data retention)

## Bucket Details

### 1. Storage Bucket
- **Bucket Name**: `acsd2p-{stage}-storage`
- **Purpose**: General file storage for the application
- **Use Cases**:
  - User profile images
  - Document uploads
  - Application assets
  - Temporary file storage
  - Backup files

#### Configuration
```typescript
{
  bucketName: 'acsd2p-{stage}-storage',
  versioned: true,
  encryption: s3.BucketEncryption.S3_MANAGED,
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
  removalPolicy: cdk.RemovalPolicy.RETAIN,
  autoDeleteObjects: false,
}
```

#### Folder Structure
```
acsd2p-{stage}-storage/
├── users/
│   ├── {user-id}/
│   │   ├── profile/
│   │   │   ├── avatar.jpg
│   │   │   └── documents/
│   │   └── uploads/
├── organizations/
│   ├── {org-id}/
│   │   ├── assets/
│   │   └── documents/
├── temp/
│   ├── uploads/
│   └── processing/
├── backups/
│   ├── daily/
│   ├── weekly/
│   └── monthly/
└── system/
    ├── logs/
    └── config/
```

#### Access Patterns
- **User Files**: `users/{user-id}/{category}/{filename}`
- **Organization Files**: `organizations/{org-id}/{category}/{filename}`
- **Temporary Files**: `temp/{type}/{timestamp}-{filename}`
- **Backup Files**: `backups/{frequency}/{date}/{filename}`

### 2. Email Attachments Bucket
- **Bucket Name**: `acsd2p-{stage}-email-attachments`
- **Purpose**: Stores email attachments and processed email content
- **Use Cases**:
  - Email attachments (PDFs, images, documents)
  - Processed email content
  - Email templates
  - Email signatures
  - Email analytics data

#### Configuration
```typescript
{
  bucketName: 'acsd2p-{stage}-email-attachments',
  versioned: true,
  encryption: s3.BucketEncryption.S3_MANAGED,
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
  removalPolicy: cdk.RemovalPolicy.RETAIN,
  autoDeleteObjects: false,
}
```

#### Folder Structure
```
acsd2p-{stage}-email-attachments/
├── conversations/
│   ├── {conversation-id}/
│   │   ├── attachments/
│   │   │   ├── {message-id}/
│   │   │   │   ├── document.pdf
│   │   │   │   ├── image.jpg
│   │   │   │   └── metadata.json
│   │   └── processed/
│   │       ├── parsed-content.json
│   │       └── extracted-data.json
├── templates/
│   ├── organization/
│   │   ├── {org-id}/
│   │   │   ├── welcome-email.html
│   │   │   ├── follow-up.html
│   │   │   └── signature.html
│   └── system/
│       ├── default-templates/
│       └── ai-generated/
├── signatures/
│   ├── {user-id}/
│   │   ├── signature.html
│   │   └── signature.txt
└── analytics/
    ├── email-metrics/
    ├── attachment-stats/
    └── processing-logs/
```

#### Access Patterns
- **Conversation Attachments**: `conversations/{conversation-id}/attachments/{message-id}/{filename}`
- **Email Templates**: `templates/organization/{org-id}/{template-name}`
- **User Signatures**: `signatures/{user-id}/{type}`
- **Analytics Data**: `analytics/{category}/{date}/{filename}`

## Data Lifecycle Management

### Versioning Strategy
- **Versioning**: Enabled for all buckets
- **Version Retention**: Configurable per bucket
- **Version Cleanup**: Automated cleanup of old versions
- **Cross-Region Replication**: Available for disaster recovery

### Lifecycle Policies

#### Storage Bucket Lifecycle
```json
{
  "Rules": [
    {
      "ID": "MoveToIA",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "temp/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        }
      ]
    },
    {
      "ID": "MoveToGlacier",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "backups/"
      },
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    },
    {
      "ID": "DeleteOldVersions",
      "Status": "Enabled",
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "NoncurrentDays": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 365
      }
    }
  ]
}
```

#### Email Attachments Bucket Lifecycle
```json
{
  "Rules": [
    {
      "ID": "MoveToIA",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "conversations/"
      },
      "Transitions": [
        {
          "Days": 60,
          "StorageClass": "STANDARD_IA"
        }
      ]
    },
    {
      "ID": "DeleteOldTemp",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "temp/"
      },
      "Expiration": {
        "Days": 7
      }
    }
  ]
}
```

## Security Configuration

### Encryption
- **At Rest**: S3 managed keys <name>
- **In Transit**: TLS 1.2+ encryption
- **Customer Managed Keys**: Available for additional security
- **Bucket Keys**: Enabled for cost optimization

### Access Control
- **IAM Policies**: Role-based access control
- **Bucket Policies**: Resource-level permissions
- **ACLs**: Disabled (bucket policies preferred)
- **Cross-Account Access**: Configurable through policies

### Public Access Blocking
```json
{
  "BlockPublicAcls": true,
  "IgnorePublicAcls": true,
  "BlockPublicPolicy": true,
  "RestrictPublicBuckets": true
}
```

## Monitoring and Alerting

### CloudWatch Metrics
- **BucketSizeBytes**: Storage usage by storage class
- **NumberOfObjects**: Object count
- **AllRequests**: Total requests
- **GetRequests**: GET requests
- **PutRequests**: PUT requests
- **DeleteRequests**: DELETE requests
- **4xxErrors**: Client error rate
- **5xxErrors**: Server error rate

### CloudTrail Integration
- **API Call Logging**: All S3 API calls logged
- **Access Analysis**: User access patterns
- **Security Monitoring**: Unusual access patterns
- **Compliance Reporting**: Audit trail for compliance

### Alerts
- **High Error Rates**: 4xx/5xx error spikes
- **Storage Thresholds**: Approaching storage limits
- **Unusual Access**: Anomalous access patterns
- **Cost Alerts**: Unexpected cost increases

## Cost Optimization

### Storage Classes
- **Standard**: Frequently accessed data
- **Standard-IA**: Infrequently accessed data (30+ days)
- **Glacier**: Long-term archival (90+ days)
- **Intelligent Tiering**: Automatic optimization

### Cost Monitoring
- **CloudWatch Cost Explorer**: Track S3 costs
- **Cost Allocation Tags**: Tag resources for cost tracking
- **Usage Alerts**: Set up alerts for cost thresholds
- **Storage Analytics**: Analyze usage patterns

### Optimization Strategies
- **Lifecycle Policies**: Automatic storage class transitions
- **Compression**: Reduce storage costs
- **Deduplication**: Eliminate duplicate objects
- **Prefix Optimization**: Improve request performance

## Backup and Recovery

### Backup Strategy
- **Versioning**: Point-in-time recovery
- **Cross-Region Replication**: Disaster recovery
- **On-Demand Backups**: Manual backup creation
- **Automated Backups**: Scheduled backup jobs

### Recovery Procedures
1. **Version Recovery**: Restore specific object versions
2. **Cross-Region Recovery**: Restore from replicated bucket
3. **Bulk Recovery**: Restore entire bucket or prefix
4. **Selective Recovery**: Restore specific objects or folders

## Performance Optimization

### Request Optimization
- **Prefix Optimization**: Organize objects with common prefixes
- **Parallel Requests**: Use multiple connections
- **Range Requests**: Download specific parts of large objects
- **Caching**: Implement appropriate caching strategies

### Transfer Optimization
- **Multipart Uploads**: Large file uploads
- **Transfer Acceleration**: Faster uploads to S3
- **Compression**: Reduce transfer times
- **Parallel Downloads**: Download multiple objects simultaneously

## Integration with Other Services

### Lambda Functions
- **Event Triggers**: S3 events trigger Lambda functions
- **Direct Access**: Lambda functions can read/write S3 objects
- **Temporary Storage**: Lambda functions can use S3 for temporary data

### SES Integration
- **Email Storage**: SES stores emails in S3 buckets
- **Attachment Processing**: Process email attachments stored in S3
- **Email Analytics**: Store email metrics and analytics

### DynamoDB Integration
- **Large Object Storage**: Store large objects in S3, metadata in DynamoDB
- **Backup Storage**: Store DynamoDB backups in S3
- **Data Export**: Export DynamoDB data to S3

## Compliance and Governance

### Data Classification
- **Public Data**: No sensitive information
- **Internal Data**: Organization-specific information
- **Confidential Data**: Sensitive business information
- **Restricted Data**: Highly sensitive information

### Retention Policies
- **User Data**: Retained based on user account lifecycle
- **Email Data**: Retained based on conversation lifecycle
- **System Data**: Retained based on operational requirements
- **Backup Data**: Retained based on disaster recovery requirements

### Audit and Compliance
- **Access Logging**: All access attempts logged
- **Change Tracking**: All modifications tracked
- **Compliance Reports**: Automated compliance reporting
- **Data Governance**: Automated data governance policies

## Best Practices

### Naming Conventions
- **Bucket Names**: `{project}-{environment}-{purpose}`
- **Object Keys**: `{category}/{id}/{subcategory}/{filename}`
- **Versioning**: Use descriptive version names
- **Tags**: Use consistent tagging strategy

### Security Best Practices
- **Least Privilege**: Grant minimum required permissions
- **Encryption**: Always encrypt sensitive data
- **Access Logging**: Enable access logging for all buckets
- **Regular Audits**: Conduct regular security audits

### Performance Best Practices
- **Prefix Optimization**: Use common prefixes for related objects
- **Parallel Operations**: Use parallel operations for bulk operations
- **Caching**: Implement appropriate caching strategies
- **Monitoring**: Monitor performance metrics regularly

### Cost Optimization Best Practices
- **Lifecycle Policies**: Implement appropriate lifecycle policies
- **Storage Classes**: Use appropriate storage classes
- **Monitoring**: Monitor costs regularly
- **Optimization**: Continuously optimize storage usage 