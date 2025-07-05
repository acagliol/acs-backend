# SES (Simple Email Service) Configuration Documentation

## Overview

The ACS infrastructure uses Amazon SES for email sending, receiving, and processing. The system includes comprehensive SES management through Lambda functions for identity creation, DKIM configuration, domain verification, and email processing workflows.

## SES Configuration

### Basic Settings
- **Service Type**: Email sending and receiving
- **Region**: us-west-1 (dev), us-east-2 (prod)
- **Sending Limits**: Based on account reputation
- **Receiving**: Configured for email processing
- **Storage**: S3 integration for email storage

## SES Identities

### Identity Types
- **Email Addresses**: Individual email addresses
- **Domains**: Complete domain verification
- **Subdomains**: Specific subdomain verification

### Identity Configuration
```typescript
// Email Identity
{
  identityType: 'email',
  emailAddress: 'noreply@example.com',
  verificationMethod: 'email'
}

// Domain Identity
{
  identityType: 'domain',
  domainName: 'example.com',
  verificationMethod: 'dns',
  dkimEnabled: true,
  dkimSigningEnabled: true
}
```

## Lambda Functions for SES Management

### 1. Create-SES-Identity
- **File**: `lambdas/Create-SES-Identity/lambda_function.py`
- **Endpoint**: `POST /api/ses/create-identity`
- **Purpose**: Creates SES identities for email sending
- **Functionality**:
  - Domain or email identity creation
  - DNS record generation
  - Verification status tracking
  - Configuration management

#### Request Format
```json
{
  "identity_type": "domain|email",
  "identity_value": "example.com|user@example.com",
  "account_id": "account-uuid",
  "session": "session-token"
}
```

#### Response Format
```json
{
  "statusCode": 200,
  "body": {
    "identity_arn": "arn:aws:ses:us-west-1:123456789012:identity/example.com",
    "verification_status": "Pending",
    "verification_token": "verification-token",
    "dns_records": [
      {
        "type": "TXT",
        "name": "_amazonses.example.com",
        "value": "verification-token"
      }
    ]
  }
}
```

### 2. Create-SES-Dkim-Records
- **File**: `lambdas/Create-SES-Dkim-Records/lambda_function.py`
- **Endpoint**: `POST /api/ses/create-dkim-records`
- **Purpose**: Generates DKIM records for email authentication
- **Functionality**:
  - DKIM key generation
  - DNS record creation
  - Email authentication setup
  - Verification handling

#### Request Format
```json
{
  "domain": "example.com",
  "account_id": "account-uuid",
  "session": "session-token"
}
```

#### Response Format
```json
{
  "statusCode": 200,
  "body": {
    "dkim_status": "Pending",
    "dkim_tokens": [
      "token1",
      "token2",
      "token3"
    ],
    "dns_records": [
      {
        "type": "CNAME",
        "name": "token1._domainkey.example.com",
        "value": "token1.dkim.amazonses.com"
      },
      {
        "type": "CNAME",
        "name": "token2._domainkey.example.com",
        "value": "token2.dkim.amazonses.com"
      },
      {
        "type": "CNAME",
        "name": "token3._domainkey.example.com",
        "value": "token3.dkim.amazonses.com"
      }
    ]
  }
}
```

### 3. Check-Domain-Status
- **File**: `lambdas/Check-Domain-Status/lambda_function.py`
- **Endpoint**: `POST /api/ses/check-domain-status`
- **Purpose**: Checks domain verification status in SES
- **Functionality**:
  - Domain status monitoring
  - Verification tracking
  - Health checks
  - Status reporting

#### Request Format
```json
{
  "domain": "example.com",
  "account_id": "account-uuid",
  "session": "session-token"
}
```

#### Response Format
```json
{
  "statusCode": 200,
  "body": {
    "domain": "example.com",
    "verification_status": "Success",
    "dkim_status": "Success",
    "sending_enabled": true,
    "reputation_metrics": {
      "bounce_rate": 0.1,
      "complaint_rate": 0.05,
      "delivery_rate": 99.85
    },
    "sending_quota": {
      "max_24_hour_send": 50000,
      "max_send_rate": 14,
      "sent_last_24_hours": 1000
    }
  }
}
```

### 4. verifyNewDomainValid
- **File**: `lambdas/verifyNewDomainValid/lambda_function.py`
- **Endpoint**: `POST /api/ses/verify-domain`
- **Purpose**: Validates new domains for SES usage
- **Functionality**:
  - Domain validation
  - DNS verification
  - Configuration testing
  - Error handling

#### Request Format
```json
{
  "domain": "example.com",
  "account_id": "account-uuid",
  "session": "session-token"
}
```

#### Response Format
```json
{
  "statusCode": 200,
  "body": {
    "domain": "example.com",
    "is_valid": true,
    "validation_errors": [],
    "dns_checks": {
      "mx_records": true,
      "spf_record": true,
      "dkim_records": true
    },
    "recommendations": [
      "Add SPF record if not present",
      "Configure DKIM for better deliverability"
    ]
  }
}
```

## Email Processing Workflow

### 1. Email Reception
1. **SES Receives Email**: Email arrives at SES
2. **SES Processing**: SES processes and validates email
3. **S3 Storage**: Email stored in S3 bucket
4. **SNS Notification**: SES sends notification to SNS topic
5. **SQS Queue**: SNS forwards message to SQS queue
6. **Lambda Processing**: SQS triggers email processing Lambda

### 2. Email Sending
1. **API Request**: Application sends email via API
2. **Lambda Processing**: Send-Email Lambda processes request
3. **SES Sending**: Lambda sends email via SES
4. **Delivery Tracking**: SES tracks email delivery
5. **Bounce/Complaint Handling**: SES handles bounces and complaints

## DNS Configuration

### Verification Records
```dns
# Domain verification
_amazonses.example.com. IN TXT "verification-token"

# DKIM records
token1._domainkey.example.com. IN CNAME token1.dkim.amazonses.com.
token2._domainkey.example.com. IN CNAME token2.dkim.amazonses.com.
token3._domainkey.example.com. IN CNAME token3.dkim.amazonses.com.

# SPF record
example.com. IN TXT "v=spf1 include:amazonses.com ~all"

# DMARC record
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
```

### DNS Record Types
- **TXT Records**: Domain verification and SPF
- **CNAME Records**: DKIM authentication
- **MX Records**: Email routing (if using SES for receiving)
- **NS Records**: DNS delegation (if using Route 53)

## Email Authentication

### SPF (Sender Policy Framework)
- **Purpose**: Prevents email spoofing
- **Record Format**: `v=spf1 include:amazonses.com ~all`
- **Implementation**: Add TXT record to domain DNS

### DKIM (DomainKeys Identified Mail)
- **Purpose**: Email integrity and authentication
- **Implementation**: CNAME records for DKIM tokens
- **Verification**: Automatic verification by SES

### DMARC (Domain-based Message Authentication)
- **Purpose**: Policy enforcement and reporting
- **Record Format**: `v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com`
- **Policy Options**: none, quarantine, reject

## Monitoring and Analytics

### CloudWatch Metrics
- **Send**: Email sending metrics
- **Bounce**: Bounce rate and types
- **Complaint**: Complaint rate and types
- **Delivery**: Delivery success rate
- **Reputation**: Sender reputation metrics

### SES Dashboard Metrics
- **Sending Statistics**: Emails sent per time period
- **Bounce Rate**: Percentage of bounced emails
- **Complaint Rate**: Percentage of complaints
- **Delivery Rate**: Percentage of delivered emails
- **Reputation Score**: Overall sender reputation

### Alerts and Notifications
- **High Bounce Rate**: Alert when bounce rate exceeds threshold
- **High Complaint Rate**: Alert when complaint rate is high
- **Low Delivery Rate**: Alert when delivery rate drops
- **Reputation Issues**: Alert when reputation score decreases

## Sending Limits and Quotas

### Account Limits
- **Sandbox Mode**: 200 emails per day, 1 email per second
- **Production Mode**: Based on account reputation
- **Request Limit**: 14 emails per second (default)
- **Daily Limit**: 50,000 emails per day (default)

### Reputation-Based Scaling
- **Good Reputation**: Higher sending limits
- **Poor Reputation**: Reduced sending limits
- **Account Suspension**: Temporary suspension for poor reputation
- **Appeal Process**: Process to restore sending privileges

## Bounce and Complaint Handling

### Bounce Types
- **Hard Bounce**: Permanent delivery failure
- **Soft Bounce**: Temporary delivery failure
- **Suppression**: Automatic suppression of bounced addresses

### Complaint Types
- **Spam Complaints**: User marks email as spam
- **Feedback Loop**: ISP feedback on complaints
- **Manual Complaints**: Direct complaints to SES

### Handling Procedures
1. **Automatic Suppression**: Bounced/complained addresses suppressed
2. **Notification**: Lambda functions notified of bounces/complaints
3. **Database Update**: Update user status in DynamoDB
4. **List Management**: Remove from active sending lists

## Security Configuration

### Access Control
- **IAM Policies**: Role-based access control
- **API Keys**: Secure API key management
- **Cross-Account Access**: Configurable through policies
- **Encryption**: Email content encrypted in transit

### Compliance
- **CAN-SPAM**: Compliance with anti-spam laws
- **GDPR**: European data protection compliance
- **CCPA**: California privacy compliance
- **Industry Standards**: Best practices for email sending

## Cost Optimization

### Pricing Model
- **Pay per Email**: Charges per email sent
- **Data Transfer**: Charges for data transfer
- **Storage**: Charges for email storage in S3
- **Additional Features**: Charges for advanced features

### Cost Monitoring
- **Usage Tracking**: Monitor email volume
- **Cost Alerts**: Set up cost thresholds
- **Optimization**: Optimize sending patterns
- **Cleanup**: Remove inactive identities

### Optimization Strategies
- **Batch Sending**: Send emails in batches
- **Template Usage**: Use email templates
- **List Management**: Maintain clean email lists
- **Reputation Management**: Maintain good sender reputation

## Best Practices

### Sending Best Practices
- **Permission-Based**: Only send to opted-in recipients
- **Clear Unsubscribe**: Provide clear unsubscribe options
- **Quality Content**: Send relevant, valuable content
- **Frequency Control**: Don't send too frequently

### Technical Best Practices
- **Authentication**: Implement SPF, DKIM, and DMARC
- **Monitoring**: Monitor sending metrics regularly
- **Testing**: Test emails before sending
- **Compliance**: Follow email marketing laws

### Reputation Management
- **Low Bounce Rate**: Keep bounce rate below 5%
- **Low Complaint Rate**: Keep complaint rate below 0.1%
- **Engagement**: Encourage recipient engagement
- **List Hygiene**: Regularly clean email lists

## Troubleshooting

### Common Issues

#### Verification Failures
- **DNS Issues**: Incorrect DNS records
- **Timeout Issues**: DNS propagation delays
- **Format Issues**: Incorrect record format
- **Permission Issues**: DNS management permissions

#### Sending Issues
- **Rate Limiting**: Exceeding sending limits
- **Authentication**: Missing or incorrect authentication
- **Content Issues**: Email content problems
- **Reputation Issues**: Poor sender reputation

#### Delivery Issues
- **Bounce Rate**: High bounce rate affecting delivery
- **Complaint Rate**: High complaint rate
- **Spam Filters**: Emails caught by spam filters
- **Blacklisting**: Domain or IP blacklisting

### Debugging Tools
- **SES Console**: SES management interface
- **CloudWatch Logs**: Lambda execution logs
- **DNS Tools**: DNS verification tools
- **Email Testing**: Email deliverability testing tools 