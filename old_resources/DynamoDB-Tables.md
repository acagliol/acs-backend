# DynamoDB Tables Documentation

## Overview

The ACS infrastructure uses DynamoDB as the primary database for storing user data, conversations, sessions, and system metadata. All tables are configured with **RemovalPolicy.RETAIN** to preserve data during deployments and use **PAY_PER_REQUEST** billing for cost optimization.

## Table Configuration

### Common Settings
- **Billing Mode**: PAY_PER_REQUEST (on-demand)
- **Removal Policy**: RETAIN (data preserved during deployments)
- **Point-in-Time Recovery**: Enabled
- **Encryption**: AWS managed keys <name>
- **Backup**: Continuous backups enabled

## Table Details

### 1. Users Table
- **Table Name**: `acsd2p-{stage}-Users`
- **Partition Key**: `id` (String)
- **Purpose**: Stores user account information and profiles
- **Data Model**:
  ```json
  {
    "id": "user-uuid",
    "email": "user@example.com",
    "name": "User Name",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z",
    "status": "active|inactive|suspended",
    "preferences": {
      "email_notifications": true,
      "ai_auto_response": true
    },
    "organization_id": "org-uuid",
    "role": "admin|user|member"
  }
  ```

#### Global Secondary Indexes (GSI)
1. **id-index**
   - Partition Key: `id`
   - Purpose: Direct user lookup by ID

2. **responseEmail-index**
   - Partition Key: `responseEmail`
   - Purpose: Lookup users by their response email address

3. **userId-createdAt-index**
   - Partition Key: `userId`
   - Sort Key: `createdAt`
   - Purpose: Chronological user activity tracking

### 2. Conversations Table
- **Table Name**: `acsd2p-{stage}-Conversations`
- **Partition Key**: `conversation_id` (String)
- **Sort Key**: `response_id` (String)
- **Purpose**: Stores individual email messages within conversations
- **Data Model**:
  ```json
  {
    "conversation_id": "conv-uuid",
    "response_id": "response-uuid",
    "message_id": "msg-uuid",
    "associated_account": "account-uuid",
    "sender_email": "sender@example.com",
    "recipient_email": "recipient@example.com",
    "subject": "Email Subject",
    "body": "Email body content",
    "timestamp": "2024-01-01T00:00:00Z",
    "is_first_email": true|false,
    "thread_id": "thread-uuid",
    "status": "received|processed|responded|scheduled",
    "ai_response": "Generated AI response",
    "ev_score": 0.85,
    "metadata": {
      "headers": {},
      "attachments": [],
      "spam_score": 0.1
    }
  }
  ```

#### Global Secondary Indexes (GSI)
1. **associated_account-index**
   - Partition Key: `associated_account`
   - Purpose: Find all conversations for a specific account

2. **associated_account-is_first_email-index**
   - Partition Key: `associated_account`
   - Sort Key: `is_first_email`
   - Purpose: Distinguish between initial and follow-up emails

3. **conversation_id-index**
   - Partition Key: `conversation_id`
   - Purpose: Direct conversation lookup

4. **message_id-index**
   - Partition Key: `message_id`
   - Purpose: Find conversations by message ID

5. **response_id-index**
   - Partition Key: `response_id`
   - Purpose: Find conversations by response ID

### 3. Threads Table
- **Table Name**: `acsd2p-{stage}-Threads`
- **Partition Key**: `conversation_id` (String)
- **Purpose**: Stores thread-level metadata and attributes
- **Data Model**:
  ```json
  {
    "conversation_id": "conv-uuid",
    "associated_account": "account-uuid",
    "thread_id": "thread-uuid",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z",
    "status": "active|closed|archived",
    "subject": "Thread Subject",
    "participants": ["user1@example.com", "user2@example.com"],
    "message_count": 5,
    "last_message_at": "2024-01-01T00:00:00Z",
    "attributes": {
      "urgency": "high|medium|low",
      "category": "support|sales|general",
      "priority": 1-10,
      "sentiment": "positive|neutral|negative"
    },
    "ai_settings": {
      "auto_response_enabled": true,
      "response_delay_hours": 2,
      "max_response_length": 500
    }
  }
  ```

#### Global Secondary Indexes (GSI)
1. **associated_account**
   - Partition Key: `associated_account`
   - Purpose: Find all threads for a specific account

2. **conversation_id-index**
   - Partition Key: `conversation_id`
   - Purpose: Direct thread lookup

### 4. Organizations Table
- **Table Name**: `acsd2p-{stage}-Organizations`
- **Partition Key**: `organization_id` (String)
- **Purpose**: Stores organization information and settings
- **Data Model**:
  ```json
  {
    "organization_id": "org-uuid",
    "name": "Organization Name",
    "domain": "example.com",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z",
    "status": "active|inactive|suspended",
    "settings": {
      "email_domain_verification": true,
      "ai_response_enabled": true,
      "max_users": 100,
      "storage_limit_gb": 10
    },
    "billing": {
      "plan": "basic|pro|enterprise",
      "next_billing_date": "2024-02-01T00:00:00Z",
      "usage": {
        "emails_processed": 1000,
        "storage_used_gb": 2.5
      }
    }
  }
  ```

### 5. OrganizationMembers Table
- **Table Name**: `acsd2p-{stage}-OrganizationMembers`
- **Partition Key**: `organization_id` (String)
- **Sort Key**: `user_id` (String)
- **Purpose**: Manages organization membership and roles
- **Data Model**:
  ```json
  {
    "organization_id": "org-uuid",
    "user_id": "user-uuid",
    "role": "owner|admin|member|viewer",
    "joined_at": "2024-01-01T00:00:00Z",
    "status": "active|inactive|pending",
    "permissions": {
      "manage_users": true,
      "view_conversations": true,
      "edit_settings": false
    },
    "invited_by": "admin-uuid",
    "last_active": "2024-01-01T00:00:00Z"
  }
  ```

#### Global Secondary Indexes (GSI)
1. **user_id-index**
   - Partition Key: `user_id`
   - Purpose: Find all organizations a user belongs to

### 6. OrganizationInvites Table
- **Table Name**: `acsd2p-{stage}-OrganizationInvites`
- **Partition Key**: `invite_id` (String)
- **Sort Key**: `timestamp` (String)
- **Purpose**: Manages organization invitations
- **Data Model**:
  ```json
  {
    "invite_id": "invite-uuid",
    "timestamp": "2024-01-01T00:00:00Z",
    "organization_id": "org-uuid",
    "email": "invitee@example.com",
    "invite_token": "secure-token",
    "invited_by": "admin-uuid",
    "role": "member|admin",
    "status": "pending|accepted|expired|cancelled",
    "expires_at": "2024-01-08T00:00:00Z",
    "accepted_at": "2024-01-05T00:00:00Z"
  }
  ```

#### Global Secondary Indexes (GSI)
1. **email-index**
   - Partition Key: `email`
   - Purpose: Find invitations by email address

2. **invite_token-index**
   - Partition Key: `invite_token`
   - Purpose: Validate invitation tokens

3. **organization_id-index**
   - Partition Key: `organization_id`
   - Purpose: Find all invitations for an organization

### 7. Sessions Table
- **Table Name**: `acsd2p-{stage}-Sessions`
- **Partition Key**: `session_id` (String)
- **TTL Attribute**: `ttl`
- **Purpose**: Stores user session information with automatic expiration
- **Data Model**:
  ```json
  {
    "session_id": "session-uuid",
    "user_id": "user-uuid",
    "account_id": "account-uuid",
    "created_at": "2024-01-01T00:00:00Z",
    "last_activity": "2024-01-01T00:00:00Z",
    "expires_at": "2024-01-08T00:00:00Z",
    "ttl": 1704067200,
    "ip_address": "192.168.1.1",
    "user_agent": "Mozilla/5.0...",
    "is_active": true,
    "metadata": {
      "login_method": "form|google",
      "device_type": "desktop|mobile|tablet"
    }
  }
  ```

### 8. RL_AI Table (Rate Limiting - AI)
- **Table Name**: `acsd2p-{stage}-RL_AI`
- **Partition Key**: `associated_account` (String)
- **Purpose**: Tracks AI operation rate limits per account
- **Data Model**:
  ```json
  {
    "associated_account": "account-uuid",
    "request_count": 150,
    "window_start": "2024-01-01T00:00:00Z",
    "window_end": "2024-01-01T01:00:00Z",
    "last_request": "2024-01-01T00:55:00Z",
    "limit": 100,
    "reset_time": "2024-01-01T01:00:00Z",
    "blocked_until": null,
    "metadata": {
      "function_calls": {
        "generate_email": 50,
        "llm_response": 100
      }
    }
  }
  ```

#### Global Secondary Indexes (GSI)
1. **associated_account-index**
   - Partition Key: `associated_account`
   - Purpose: Direct rate limit lookup

### 9. RL_AWS Table (Rate Limiting - AWS)
- **Table Name**: `acsd2p-{stage}-RL_AWS`
- **Partition Key**: `associated_account` (String)
- **Purpose**: Tracks AWS API rate limits per account
- **Data Model**:
  ```json
  {
    "associated_account": "account-uuid",
    "aws_requests": 950,
    "window_start": "2024-01-01T00:00:00Z",
    "window_end": "2024-01-01T01:00:00Z",
    "last_request": "2024-01-01T00:55:00Z",
    "limit": 1000,
    "reset_time": "2024-01-01T01:00:00Z",
    "throttled_requests": 5,
    "metadata": {
      "service_calls": {
        "dynamodb": 400,
        "s3": 300,
        "ses": 250
      }
    }
  }
  ```

#### Global Secondary Indexes (GSI)
1. **associated_account-index**
   - Partition Key: `associated_account`
   - Purpose: Direct rate limit lookup

### 10. EVDataCollection Table
- **Table Name**: `acsd2p-{stage}-EVDataCollection`
- **Partition Key**: `conversation_id` (String)
- **Purpose**: Stores Expected Value calculation data
- **Data Model**:
  ```json
  {
    "conversation_id": "conv-uuid",
    "ev_score": 0.85,
    "calculation_date": "2024-01-01T00:00:00Z",
    "factors": {
      "urgency": 0.8,
      "priority": 0.9,
      "sentiment": 0.7,
      "response_time": 0.6
    },
    "algorithm_version": "1.2.0",
    "confidence_score": 0.92,
    "recommendations": [
      "Respond within 2 hours",
      "Include pricing information"
    ],
    "metadata": {
      "calculation_time_ms": 150,
      "data_points_used": 25
    }
  }
  ```

#### Global Secondary Indexes (GSI)
1. **conversation_id-index**
   - Partition Key: `conversation_id`
   - Purpose: Direct EV data lookup

### 11. LLMDataCollection Table
- **Table Name**: `acsd2p-{stage}-LLMDataCollection`
- **Partition Key**: `conversation_id` (String)
- **Purpose**: Stores LLM interaction data for analysis
- **Data Model**:
  ```json
  {
    "conversation_id": "conv-uuid",
    "model_used": "meta-llama/Llama-3.3-70B-Instruct-Turbo",
    "prompt_tokens": 150,
    "response_tokens": 200,
    "total_tokens": 350,
    "response_time_ms": 2500,
    "quality_score": 0.88,
    "generated_at": "2024-01-01T00:00:00Z",
    "prompt": "Original prompt text",
    "response": "Generated response text",
    "metadata": {
      "temperature": 0.7,
      "top_p": 0.7,
      "max_tokens": 512,
      "cost_usd": 0.0025
    }
  }
  ```

#### Global Secondary Indexes (GSI)
1. **conversation_id-index**
   - Partition Key: `conversation_id`
   - Purpose: Direct LLM data lookup

### 12. LLMReportData Table
- **Table Name**: `acsd2p-{stage}-LLMReportData`
- **Partition Key**: `report_id` (String)
- **Purpose**: Stores aggregated LLM usage reports
- **Data Model**:
  ```json
  {
    "report_id": "report-uuid",
    "account_id": "account-uuid",
    "report_period": "2024-01",
    "generated_at": "2024-01-01T00:00:00Z",
    "total_requests": 1500,
    "total_tokens": 450000,
    "total_cost_usd": 12.50,
    "average_response_time_ms": 2200,
    "average_quality_score": 0.85,
    "model_usage": {
      "meta-llama/Llama-3.3-70B-Instruct-Turbo": {
        "requests": 1200,
        "tokens": 360000,
        "cost": 10.00
      }
    },
    "function_breakdown": {
      "generate_email": 800,
      "llm_response": 700
    }
  }
  ```

#### Global Secondary Indexes (GSI)
1. **report_id-index**
   - Partition Key: `report_id`
   - Purpose: Direct report lookup

### 13. Invocations Table
- **Table Name**: `acsd2p-{stage}-Invocations`
- **Partition Key**: `id` (String)
- **Purpose**: Tracks Lambda function invocations for monitoring
- **Data Model**:
  ```json
  {
    "id": "invocation-uuid",
    "associated_account": "account-uuid",
    "function_name": "LoginUser",
    "invoked_at": "2024-01-01T00:00:00Z",
    "duration_ms": 150,
    "memory_used_mb": 128,
    "status": "success|error|timeout",
    "error_message": "Error details if failed",
    "request_id": "aws-request-id",
    "cold_start": true,
    "metadata": {
      "http_method": "POST",
      "endpoint": "/api/auth/login",
      "user_agent": "Mozilla/5.0..."
    }
  }
  ```

#### Global Secondary Indexes (GSI)
1. **associated_account-index**
   - Partition Key: `associated_account`
   - Purpose: Find invocations by account

2. **id-index**
   - Partition Key: `id`
   - Purpose: Direct invocation lookup

## Data Access Patterns

### Common Queries

1. **User Authentication**
   ```python
   # Find user by email
   table.query(
       IndexName='responseEmail-index',
       KeyConditionExpression=Key('responseEmail').eq(email)
   )
   ```

2. **Conversation Threading**
   ```python
   # Get all messages in a conversation
   table.query(
       KeyConditionExpression=Key('conversation_id').eq(conv_id)
   )
   ```

3. **Account-based Filtering**
   ```python
   # Get all conversations for an account
   table.query(
       IndexName='associated_account-index',
       KeyConditionExpression=Key('associated_account').eq(account_id)
   )
   ```

4. **Session Management**
   ```python
   # Find active sessions for a user
   table.query(
       KeyConditionExpression=Key('user_id').eq(user_id),
       FilterExpression=Attr('is_active').eq(True)
   )
   ```

## Backup and Recovery

### Backup Strategy
- **Continuous Backups**: Enabled for all tables
- **Point-in-Time Recovery**: Available for 35 days
- **On-Demand Backups**: Can be created manually
- **Cross-Region Replication**: Available for disaster recovery

### Recovery Procedures
1. **Point-in-Time Recovery**: Restore to any moment within 35 days
2. **On-Demand Backup**: Restore from specific backup point
3. **Cross-Region**: Restore from replicated table in another region

## Monitoring and Alerting

### CloudWatch Metrics
- **Consumed Read/Write Capacity Units**
- **Throttled Requests**
- **User Errors**
- **System Errors**
- **Item Count**
- **Table Size**

### Alerts
- High throttling rates
- Error rate spikes
- Table size approaching limits
- Backup failures

## Cost Optimization

### Billing Mode
- **PAY_PER_REQUEST**: Charges only for actual requests
- **No minimum capacity**: No charges for idle time
- **Automatic scaling**: Handles traffic spikes automatically

### Cost Monitoring
- **CloudWatch Cost Explorer**: Track DynamoDB costs
- **Cost Allocation Tags**: Tag resources for cost tracking
- **Usage Alerts**: Set up alerts for cost thresholds

## Security

### Encryption
- **At Rest**: AWS managed keys <name>
- **In Transit**: TLS 1.2+ encryption
- **Customer Managed Keys**: Available for additional security

### Access Control
- **IAM Policies**: Role-based access control
- **Resource Policies**: Table-level permissions
- **Condition Keys**: Fine-grained access control

### Audit
- **CloudTrail**: API call logging
- **DynamoDB Streams**: Change tracking
- **Access Analyzer**: Permission analysis

## Performance Optimization

### Indexing Strategy
- **Primary Key**: Optimized for most common access patterns
- **GSI**: Support for additional query patterns
- **LSI**: Local secondary indexes for range queries

### Query Optimization
- **Projection**: Only retrieve needed attributes
- **Filtering**: Use indexes for efficient filtering
- **Pagination**: Use LastEvaluatedKey for large result sets

### Capacity Planning
- **Auto Scaling**: Automatic capacity adjustment
- **Provisioned Mode**: Available for predictable workloads
- **On-Demand Mode**: Current configuration for variable workloads 