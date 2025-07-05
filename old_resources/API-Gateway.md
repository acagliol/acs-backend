# API Gateway Documentation

## Overview

The ACS infrastructure uses Amazon API Gateway to provide a RESTful API interface for all Lambda functions. The API is configured with CORS support, comprehensive logging, and automatic integration with Lambda functions.

## API Configuration

### Basic Settings
- **API Type**: REST API
- **API Name**: `acsd2p-{stage}-API`
- **Description**: ACS API for {stage} environment
- **Stage Name**: `dev` or `prod`
- **Logging Level**: INFO
- **Data Trace**: Enabled
- **CORS**: Configured for all origins

### CORS Configuration
```json
{
  "allowOrigins": "*",
  "allowMethods": "GET, POST, PUT, DELETE, OPTIONS",
  "allowHeaders": [
    "Content-Type",
    "Authorization",
    "X-Amz-Date",
    "X-Api-Key",
    "X-Amz-Security-Token"
  ],
  "allowCredentials": true
}
```

## API Endpoints

### 🔐 Authentication Endpoints

#### 1. User Login
- **Endpoint**: `POST /api/auth/login`
- **Lambda Function**: `LoginUser`
- **Purpose**: Authenticates users and creates sessions
- **Request Body**:
  ```json
  {
    "email": "user@example.com",
    "password": "password123",
    "provider": "form|google",
    "name": "User Name" // Optional for Google OAuth
  }
  ```
- **Response**:
  ```json
  {
    "statusCode": 200,
    "body": {
      "message": "Login successful",
      "user": {
        "id": "user-uuid",
        "email": "user@example.com",
        "name": "User Name"
      }
    },
    "headers": {
      "Set-Cookie": "session_id=abc123; HttpOnly; Secure; SameSite=Strict"
    }
  }
  ```

#### 2. Authorization Check
- **Endpoint**: `POST /api/auth/authorize`
- **Lambda Function**: `Authorize`
- **Purpose**: Validates session tokens and permissions
- **Request Body**:
  ```json
  {
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```
- **Response**:
  ```json
  {
    "statusCode": 200,
    "body": {
      "authorized": true,
      "permissions": ["read", "write"]
    }
  }
  ```

### 📝 Session Management

#### 3. Create New Session
- **Endpoint**: `POST /api/session/create`
- **Lambda Function**: `CreateNewSession`
- **Purpose**: Creates new user sessions with TTL
- **Request Body**:
  ```json
  {
    "user_id": "user-uuid",
    "account_id": "account-uuid",
    "ip_address": "192.168.1.1",
    "user_agent": "Mozilla/5.0..."
  }
  ```
- **Response**:
  ```json
  {
    "statusCode": 200,
    "body": {
      "session_id": "session-uuid",
      "expires_at": "2024-01-08T00:00:00Z"
    }
  }
  ```

### 🗄️ Database Operations

#### 4. Database Select
- **Endpoint**: `POST /api/db/select`
- **Lambda Function**: `DBSelect`
- **Purpose**: Secure database querying with account-based filtering
- **Request Body**:
  ```json
  {
    "table_name": "Users",
    "index_name": "responseEmail-index",
    "key_name": "responseEmail",
    "key_value": "user@example.com",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```
- **Response**:
  ```json
  {
    "statusCode": 200,
    "body": {
      "items": [
        {
          "id": "user-uuid",
          "email": "user@example.com",
          "name": "User Name"
        }
      ],
      "count": 1
    }
  }
  ```

#### 5. Database Update
- **Endpoint**: `POST /api/db/update`
- **Lambda Function**: `DBUpdate`
- **Purpose**: Updates DynamoDB records with validation
- **Request Body**:
  ```json
  {
    "table_name": "Users",
    "key": {
      "id": "user-uuid"
    },
    "updates": {
      "name": "Updated Name",
      "updated_at": "2024-01-01T00:00:00Z"
    },
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

#### 6. Database Delete
- **Endpoint**: `POST /api/db/delete`
- **Lambda Function**: `DBDelete`
- **Purpose**: Deletes DynamoDB records with authorization
- **Request Body**:
  ```json
  {
    "table_name": "Users",
    "key": {
      "id": "user-uuid"
    },
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

#### 7. Batch Database Select
- **Endpoint**: `POST /api/db/batch-select`
- **Lambda Function**: `DBBatchSelect`
- **Purpose**: Batch database operations for efficiency
- **Request Body**:
  ```json
  {
    "queries": [
      {
        "table_name": "Users",
        "index_name": "responseEmail-index",
        "key_name": "responseEmail",
        "key_value": "user1@example.com"
      },
      {
        "table_name": "Conversations",
        "index_name": "associated_account-index",
        "key_name": "associated_account",
        "key_value": "account-uuid"
      }
    ],
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

### 📧 Email Operations

#### 8. Send Email
- **Endpoint**: `POST /api/email/send`
- **Lambda Function**: `Send-Email`
- **Purpose**: Sends emails via AWS SES
- **Request Body**:
  ```json
  {
    "to": "recipient@example.com",
    "from": "sender@example.com",
    "subject": "Email Subject",
    "body": "Email body content",
    "html_body": "<html>Email HTML content</html>",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

#### 9. Generate Email
- **Endpoint**: `POST /api/email/generate`
- **Lambda Function**: `GenerateEmail`
- **Purpose**: AI-powered email generation using Together AI
- **Request Body**:
  ```json
  {
    "sender": "sender@example.com",
    "recipient": "recipient@example.com",
    "base_message": "Generate a professional follow-up email",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```
- **Response**:
  ```json
  {
    "statusCode": 200,
    "body": {
      "subject": "Generated Subject",
      "body": "Generated email body",
      "sender": "sender@example.com",
      "recipient": "recipient@example.com"
    }
  }
  ```

### 🤖 AI Operations

#### 10. AI Rate Limiting
- **Endpoint**: `POST /api/ai/rate-limit`
- **Lambda Function**: `RateLimitAI`
- **Purpose**: Rate limiting for AI operations
- **Request Body**:
  ```json
  {
    "client_id": "account-uuid",
    "session": "session-token",
    "operation": "generate_email"
  }
  ```

#### 11. AWS Rate Limiting
- **Endpoint**: `POST /api/ai/rate-limit-aws`
- **Lambda Function**: `RateLimitAWS`
- **Purpose**: Rate limiting for AWS API operations
- **Request Body**:
  ```json
  {
    "client_id": "account-uuid",
    "session": "session-token",
    "service": "dynamodb"
  }
  ```

#### 12. LLM Response Generation
- **Endpoint**: `POST /api/ai/llm-response`
- **Lambda Function**: `LCPLlmResponse`
- **Purpose**: Generates AI responses for email conversations
- **Request Body**:
  ```json
  {
    "conversation_id": "conv-uuid",
    "account_id": "account-uuid",
    "context": "Previous conversation context",
    "session": "session-token"
  }
  ```

#### 13. Expected Value Generation
- **Endpoint**: `POST /api/ai/generate-ev`
- **Lambda Function**: `GenerateEV`
- **Purpose**: Generates Expected Value calculations for conversations
- **Request Body**:
  ```json
  {
    "conversation_id": "conv-uuid",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

#### 14. Event Parsing
- **Endpoint**: `POST /api/ai/parse-event`
- **Lambda Function**: `ParseEvent`
- **Purpose**: Parses and extracts structured data from events
- **Request Body**:
  ```json
  {
    "event_data": "Raw event data",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

#### 15. Thread Attributes
- **Endpoint**: `POST /api/ai/get-thread-attrs`
- **Lambda Function**: `getThreadAttrs`
- **Purpose**: Extracts attributes from email threads
- **Request Body**:
  ```json
  {
    "conversationId": "conv-uuid",
    "accountId": "account-uuid"
  }
  ```

#### 16. Thread Information Retrieval
- **Endpoint**: `POST /api/ai/retrieve-thread-info`
- **Lambda Function**: `Retrieve-Thread-Information`
- **Purpose**: Retrieves comprehensive thread information
- **Request Body**:
  ```json
  {
    "conversation_id": "conv-uuid",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

### 👥 User Management

#### 17. Get User Conversations
- **Endpoint**: `POST /api/user/conversations`
- **Lambda Function**: `GetUserConversations`
- **Purpose**: Retrieves user conversation history
- **Request Body**:
  ```json
  {
    "account_id": "account-uuid",
    "session": "session-token",
    "limit": 50,
    "offset": 0
  }
  ```

#### 18. Process New User (Supabase)
- **Endpoint**: `POST /api/user/process-new`
- **Lambda Function**: `ProcessNewUserSupabase`
- **Purpose**: Processes new user registrations from Supabase
- **Request Body**:
  ```json
  {
    "user_id": "user-uuid",
    "email": "user@example.com",
    "name": "User Name",
    "organization_id": "org-uuid"
  }
  ```

#### 19. Delete User (Supabase)
- **Endpoint**: `POST /api/user/delete`
- **Lambda Function**: `DeleteUserSupabase`
- **Purpose**: Handles user account deletion
- **Request Body**:
  ```json
  {
    "user_id": "user-uuid",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

### 🏢 Organization Management

#### 20. Organization CRUD
- **Endpoint**: `POST /api/organizations/crud`
- **Lambda Function**: `Organizations-Crud`
- **Purpose**: CRUD operations for organizations
- **Request Body**:
  ```json
  {
    "operation": "create|read|update|delete",
    "organization_data": {
      "name": "Organization Name",
      "domain": "example.com"
    },
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

#### 21. Organization Members
- **Endpoint**: `POST /api/organizations/members`
- **Lambda Function**: `Organizations-Members`
- **Purpose**: Manages organization membership
- **Request Body**:
  ```json
  {
    "operation": "invite|remove|list|update_role",
    "organization_id": "org-uuid",
    "user_email": "user@example.com",
    "role": "admin|member|viewer",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

### 🔧 SES Management

#### 22. Create SES Identity
- **Endpoint**: `POST /api/ses/create-identity`
- **Lambda Function**: `Create-SES-Identity`
- **Purpose**: Creates SES identities for email sending
- **Request Body**:
  ```json
  {
    "domain": "example.com",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

#### 23. Create SES DKIM Records
- **Endpoint**: `POST /api/ses/create-dkim-records`
- **Lambda Function**: `Create-SES-Dkim-Records`
- **Purpose**: Generates DKIM records for email authentication
- **Request Body**:
  ```json
  {
    "domain": "example.com",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

#### 24. Check Domain Status
- **Endpoint**: `POST /api/ses/check-domain-status`
- **Lambda Function**: `Check-Domain-Status`
- **Purpose**: Checks domain verification status in SES
- **Request Body**:
  ```json
  {
    "domain": "example.com",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

#### 25. Verify New Domain
- **Endpoint**: `POST /api/ses/verify-domain`
- **Lambda Function**: `verifyNewDomainValid`
- **Purpose**: Validates new domains for SES usage
- **Request Body**:
  ```json
  {
    "domain": "example.com",
    "account_id": "account-uuid",
    "session": "session-token"
  }
  ```

## Error Handling

### Standard Error Responses

#### 400 Bad Request
```json
{
  "statusCode": 400,
  "body": {
    "error": "Bad Request",
    "message": "Missing required fields: account_id and session"
  }
}
```

#### 401 Unauthorized
```json
{
  "statusCode": 401,
  "body": {
    "error": "Unauthorized",
    "message": "Invalid or expired session"
  }
}
```

#### 429 Too Many Requests
```json
{
  "statusCode": 429,
  "body": {
    "error": "Rate limit exceeded",
    "message": "You have exceeded your rate limit. Please try again later."
  }
}
```

#### 500 Internal Server Error
```json
{
  "statusCode": 500,
  "body": {
    "error": "Internal Server Error",
    "message": "An unexpected error occurred"
  }
}
```

## Authentication & Authorization

### Session-Based Authentication
- All endpoints require valid session tokens
- Sessions are stored in DynamoDB with TTL
- Session validation happens in each Lambda function
- Rate limiting is applied per account

### Account-Based Access Control
- All data operations are filtered by `account_id`
- Users can only access their own data
- Organization membership controls access to shared resources

## Rate Limiting

### AI Operations
- Per-account rate limiting for AI functions
- Token bucket algorithm implementation
- Configurable limits per operation type

### AWS API Operations
- Per-account rate limiting for AWS services
- Prevents API throttling
- Cost optimization through request management

## Monitoring & Logging

### CloudWatch Integration
- **Access Logs**: All API requests are logged
- **Execution Logs**: Lambda function execution details
- **Error Logs**: Detailed error information
- **Performance Metrics**: Response times and throughput

### Metrics Tracked
- **Request Count**: Total API requests
- **4XX Errors**: Client error rate
- **5XX Errors**: Server error rate
- **Latency**: Response time percentiles
- **Cache Hit Rate**: API Gateway cache performance

## CORS Configuration

### Preflight Handling
- Automatic OPTIONS request handling
- CORS headers applied to all responses
- Support for multiple origins
- Credential support enabled

### Security Headers
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS`
- `Access-Control-Allow-Headers: Content-Type, Authorization, X-Amz-Date, X-Api-Key, X-Amz-Security-Token`
- `Access-Control-Allow-Credentials: true`

## Deployment

### Environment-Specific URLs
- **Development**: `https://{api-id}.execute-api.us-west-1.amazonaws.com/dev/`
- **Production**: `https://{api-id}.execute-api.us-east-2.amazonaws.com/prod/`

### Stage Management
- Separate stages for dev and prod environments
- Independent deployment and rollback capabilities
- Stage-specific configuration and monitoring

## Testing

### API Testing Tools
- **Postman**: Manual API testing
- **AWS CLI**: Command-line testing
- **curl**: Simple HTTP requests
- **AWS Console**: Built-in API testing

### Test Examples

#### Login Test
```bash
curl -X POST https://{api-id}.execute-api.us-west-1.amazonaws.com/dev/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "provider": "form"
  }'
```

#### Database Query Test
```bash
curl -X POST https://{api-id}.execute-api.us-west-1.amazonaws.com/dev/api/db/select \
  -H "Content-Type: application/json" \
  -H "Cookie: session_id=abc123" \
  -d '{
    "table_name": "Users",
    "index_name": "responseEmail-index",
    "key_name": "responseEmail",
    "key_value": "test@example.com",
    "account_id": "account-uuid",
    "session": "session-token"
  }'
```

## Security Considerations

### Input Validation
- All inputs are validated in Lambda functions
- SQL injection prevention through parameterized queries
- XSS protection through output encoding

### Data Protection
- Sensitive data encrypted in transit and at rest
- Session tokens are secure and HttpOnly
- Account-based data isolation

### API Security
- HTTPS enforcement
- CORS properly configured
- Rate limiting to prevent abuse
- Comprehensive error handling without information leakage 