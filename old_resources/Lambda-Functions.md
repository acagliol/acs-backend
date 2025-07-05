# Lambda Functions Documentation

## Overview

The ACS (Automated Communication System) infrastructure contains 30+ Lambda functions that handle various aspects of the email automation, user management, AI processing, and database operations. All functions are automatically deployed from the `lambdas/` directory and receive shared environment variables for cross-function communication.

## Function Categories

### 🔐 Authentication & Authorization

#### 1. LoginUser
- **File**: `lambdas/LoginUser/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/auth/login`
- **Purpose**: Handles user authentication for both form-based and Google OAuth login
- **Key Features**:
  - Supports multiple authentication providers (form, google)
  - Creates session tokens and stores them in DynamoDB
  - Integrates with Cognito for user management
  - Returns secure cookies for session management
- **Dependencies**: `login_logic.py`, `utils.py`, `config.py`
- **Environment Variables**: `SESSIONS_TABLE`, `CORS_FUNCTION_NAME`

#### 2. Authorize
- **File**: `lambdas/Authorize/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/auth/authorize`
- **Purpose**: Validates session tokens and user permissions
- **Key Features**:
  - Session token validation
  - User permission checking
  - Account-based access control
- **Dependencies**: `utils.py`, `config.py`

#### 3. CreateNewSession
- **File**: `lambdas/CreateNewSession/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/session/create`
- **Purpose**: Creates new user sessions with TTL
- **Key Features**:
  - Generates unique session IDs
  - Sets session expiration (TTL)
  - Stores session data in DynamoDB
- **Dependencies**: `utils.py`, `config.py`

### 🗄️ Database Operations

#### 4. DBSelect
- **File**: `lambdas/DBSelect/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/db/select`
- **Purpose**: Secure database querying with account-based filtering
- **Key Features**:
  - Account-based record filtering
  - GSI (Global Secondary Index) support
  - Rate limiting integration
  - CORS headers management
- **Request Format**:
  ```json
  {
    "table_name": "string",
    "index_name": "string", 
    "key_name": "string",
    "key_value": "string",
    "account_id": "string",
    "session": "string"
  }
  ```

#### 5. DBUpdate
- **File**: `lambdas/DBUpdate/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/db/update`
- **Purpose**: Updates DynamoDB records with validation
- **Key Features**:
  - Account-based update validation
  - Conditional updates
  - Audit trail support
- **Dependencies**: `utils.py`, `config.py`

#### 6. DBDelete
- **File**: `lambdas/DBDelete/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/db/delete`
- **Purpose**: Deletes DynamoDB records with authorization
- **Key Features**:
  - Account-based deletion validation
  - Soft delete options
  - Cascade deletion support
- **Dependencies**: `utils.py`, `config.py`

#### 7. DBBatchSelect
- **File**: `lambdas/DBBatchSelect/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/db/batch-select`
- **Purpose**: Batch database operations for efficiency
- **Key Features**:
  - Batch query operations
  - Parallel processing
  - Result aggregation
- **Dependencies**: `utils.py`, `config.py`

### 📧 Email Processing

#### 8. Send-Email
- **File**: `lambdas/Send-Email/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/email/send`
- **Purpose**: Sends emails via AWS SES
- **Key Features**:
  - SES integration
  - Email templating
  - Delivery tracking
  - Bounce handling
- **Dependencies**: `send_email_logic.py`, `utils.py`, `config.py`

#### 9. GenerateEmail
- **File**: `lambdas/GenerateEmail/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/email/generate`
- **Purpose**: AI-powered email generation using Together AI
- **Key Features**:
  - LLM integration (Llama-3.3-70B-Instruct-Turbo)
  - Subject and body extraction
  - Professional email formatting
  - Customizable prompts
- **AI Model**: `meta-llama/Llama-3.3-70B-Instruct-Turbo`
- **Parameters**:
  - Max tokens: 512
  - Temperature: 0.7
  - Top-p: 0.7
  - Top-k: 50

#### 10. Process-SQS-Queued-Emails
- **File**: `lambdas/Process-SQS-Queued-Emails/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Purpose**: Processes emails from SQS queue (triggered by SES)
- **Key Features**:
  - S3 email retrieval
  - Email parsing and threading
  - Spam detection
  - Conversation management
  - AI response generation
  - Email scheduling
- **Dependencies**: 
  - `email_processor.py`
  - `parser.py`
  - `scheduling.py`
  - `llm_interface.py`
  - `db.py`
  - `config.py`
- **Integration Points**:
  - S3 for email storage
  - SQS for queue processing
  - DynamoDB for conversation storage
  - Lambda functions for AI processing

### 🤖 AI & Machine Learning

#### 11. LCPLlmResponse
- **File**: `lambdas/LCPLlmResponse/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ai/llm-response`
- **Purpose**: Generates AI responses for email conversations
- **Key Features**:
  - Context-aware responses
  - Conversation history integration
  - Response quality scoring
  - Multi-turn dialogue support
- **Dependencies**: `llm_interface.py`, `prompts.py`, `db.py`, `utils.py`, `config.py`

#### 12. GenerateEV
- **File**: `lambdas/GenerateEV/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ai/generate-ev`
- **Purpose**: Generates Expected Value (EV) calculations for conversations
- **Key Features**:
  - EV calculation algorithms
  - Risk assessment
  - Decision tree analysis
  - Flag-based LLM processing
- **Dependencies**: `ev_calculator.py`, `ev_logic.py`, `flag_llm.py`, `db.py`, `utils.py`, `config.py`

#### 13. ParseEvent
- **File**: `lambdas/ParseEvent/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ai/parse-event`
- **Purpose**: Parses and extracts structured data from events
- **Key Features**:
  - Event pattern recognition
  - Data extraction
  - Schema validation
  - Metadata generation
- **Dependencies**: `utils.py`, `config.py`

#### 14. getThreadAttrs
- **File**: `lambdas/getThreadAttrs/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ai/get-thread-attrs`
- **Purpose**: Extracts attributes from email threads
- **Key Features**:
  - Thread analysis
  - Attribute extraction
  - Metadata generation
  - Pattern recognition
- **Dependencies**: `llm_interface.py`, `db.py`, `config.py`

#### 15. Retrieve-Thread-Information
- **File**: `lambdas/Retrieve-Thread-Information/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ai/retrieve-thread-info`
- **Purpose**: Retrieves comprehensive thread information
- **Key Features**:
  - Thread reconstruction
  - Message threading
  - Conversation flow analysis
  - Historical context
- **Dependencies**: `get_all_threads.py`, `get_thread_by_id.py`, `common.py`

### 🚦 Rate Limiting

#### 16. RateLimitAI
- **File**: `lambdas/RateLimitAI/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ai/rate-limit`
- **Purpose**: Rate limiting for AI operations
- **Key Features**:
  - Per-account rate limiting
  - Token bucket algorithm
  - Sliding window tracking
  - Configurable limits
- **Dependencies**: `rate_limit_logic.py`, `utils.py`, `config.py`

#### 17. RateLimitAWS
- **File**: `lambdas/RateLimitAWS/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ai/rate-limit-aws`
- **Purpose**: Rate limiting for AWS API operations
- **Key Features**:
  - AWS API rate limit management
  - Request throttling
  - Cost optimization
  - Usage tracking
- **Dependencies**: `rate_limit_logic.py`, `utils.py`, `config.py`

### 👥 User Management

#### 18. GetUserConversations
- **File**: `lambdas/GetUserConversations/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/user/conversations`
- **Purpose**: Retrieves user conversation history
- **Key Features**:
  - Conversation listing
  - Pagination support
  - Filtering options
  - Search capabilities
- **Dependencies**: `utils.py`, `config.py`

#### 19. ProcessNewUserSupabase
- **File**: `lambdas/ProcessNewUserSupabase/index.mjs`
- **Runtime**: Node.js 18.x
- **Handler**: `index.handler`
- **Endpoint**: `POST /api/user/process-new`
- **Purpose**: Processes new user registrations from Supabase
- **Key Features**:
  - User onboarding
  - Profile creation
  - Initial setup
  - Welcome email sending
- **Dependencies**: `user_processor.mjs`, `utils.mjs`, `config.mjs`

#### 20. DeleteUserSupabase
- **File**: `lambdas/DeleteUserSupabase/index.mjs`
- **Runtime**: Node.js 18.x
- **Handler**: `index.handler`
- **Endpoint**: `POST /api/user/delete`
- **Purpose**: Handles user account deletion
- **Key Features**:
  - Account cleanup
  - Data deletion
  - Cascade operations
  - Audit logging

### 🏢 Organization Management

#### 21. Organizations-Crud
- **File**: `lambdas/Organizations-Crud/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/organizations/crud`
- **Purpose**: CRUD operations for organizations
- **Key Features**:
  - Organization creation/update/deletion
  - Member management
  - Permission handling
  - Hierarchy management
- **Dependencies**: `utils.py`, `config.py`

#### 22. Organizations-Members
- **File**: `lambdas/Organizations-Members/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/organizations/members`
- **Purpose**: Manages organization membership
- **Key Features**:
  - Member invitations
  - Role management
  - Access control
  - Member listing
- **Dependencies**: `utils.py`, `config.py`

### 🔧 SES (Simple Email Service) Management

#### 23. Create-SES-Identity
- **File**: `lambdas/Create-SES-Identity/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ses/create-identity`
- **Purpose**: Creates SES identities for email sending
- **Key Features**:
  - Domain verification
  - Email identity setup
  - DNS record generation
  - Configuration management

#### 24. Create-SES-Dkim-Records
- **File**: `lambdas/Create-SES-Dkim-Records/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ses/create-dkim-records`
- **Purpose**: Generates DKIM records for email authentication
- **Key Features**:
  - DKIM key generation
  - DNS record creation
  - Email authentication setup
  - Verification handling

#### 25. Check-Domain-Status
- **File**: `lambdas/Check-Domain-Status/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ses/check-domain-status`
- **Purpose**: Checks domain verification status in SES
- **Key Features**:
  - Domain status monitoring
  - Verification tracking
  - Health checks
  - Status reporting

#### 26. verifyNewDomainValid
- **File**: `lambdas/verifyNewDomainValid/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Endpoint**: `POST /api/ses/verify-domain`
- **Purpose**: Validates new domains for SES usage
- **Key Features**:
  - Domain validation
  - DNS verification
  - Configuration testing
  - Error handling

### 🛠️ Utility Functions

#### 27. Allow-Cors
- **File**: `lambdas/Allow-Cors/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Purpose**: Provides CORS headers for API responses
- **Key Features**:
  - CORS header generation
  - Cross-origin support
  - Security headers
  - Preflight handling

#### 28. Get-Cors
- **File**: `lambdas/Get-Cors/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Purpose**: Retrieves CORS configuration
- **Key Features**:
  - CORS policy retrieval
  - Configuration management
  - Dynamic CORS handling

#### 29. API-Authorizer
- **File**: `lambdas/API-Authorizer/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Purpose**: API Gateway authorizer for request validation
- **Key Features**:
  - Request authorization
  - Token validation
  - Policy generation
  - Access control

#### 30. Test-Scheduler
- **File**: `lambdas/Test-Scheduler/lambda_function.py`
- **Runtime**: Python 3.11
- **Handler**: `lambda_function.handler`
- **Purpose**: Testing and validation of scheduling functionality
- **Key Features**:
  - Schedule testing
  - Validation workflows
  - Debug functionality
  - Performance testing

## Shared Environment Variables

All Lambda functions receive these environment variables:

```bash
# Core Configuration
STAGE=dev|prod
AWS_ACCOUNT_ID=872515253712
CDK_AWS_REGION=us-west-1|us-east-2

# Cognito Configuration
USER_POOL_ID=us-west-1_xxxxxxxxx
USER_POOL_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx

# Queue Configuration
EMAIL_PROCESS_QUEUE_URL=https://sqs.us-west-1.amazonaws.com/...

# API Configuration
API_GATEWAY_ID=xxxxxxxxxx

# Function Names (for cross-function communication)
LOGINUSER_FUNCTION_NAME=acsd2p-dev-LoginUser
DBSELECT_FUNCTION_NAME=acsd2p-dev-DBSelect
# ... (all function names)

# Table Names
USERS_TABLE_NAME=acsd2p-dev-Users
CONVERSATIONS_TABLE_NAME=acsd2p-dev-Conversations
# ... (all table names)

# Bucket Names
STORAGE_BUCKET_NAME=acsd2p-dev-storage
EMAILATTACHMENTS_BUCKET_NAME=acsd2p-dev-email-attachments
```

## Runtime Detection

The CDK automatically detects the runtime based on file presence:

- **Python 3.11**: If `lambda_function.py` or `requirements.txt` exists
- **Node.js 18.x**: If `index.js`, `index.mjs`, or `package.json` exists

## Handler Detection

- **Python**: `lambda_function.handler`
- **Node.js**: `index.handler` (for both .js and .mjs files)

## Permissions

All Lambda functions receive these IAM permissions:

- **DynamoDB**: Full read/write access to all tables
- **S3**: Full read/write access to all buckets
- **SQS**: Send and receive messages from email processing queue
- **Cognito**: Admin user management operations
- **CloudWatch**: Logging and monitoring
- **Lambda**: Cross-function invocation

## Deployment

Lambda functions are automatically deployed when:
1. New function directory is added to `lambdas/`
2. Function code is modified
3. Dependencies are updated
4. Environment variables change

## Monitoring

All functions are monitored through:
- CloudWatch Logs
- CloudWatch Metrics
- X-Ray tracing (if enabled)
- Custom error tracking

## Error Handling

Standard error handling pattern:
```python
try:
    # Function logic
    return create_response(200, result)
except LambdaError as e:
    return create_response(e.status_code, {"message": e.message})
except Exception as e:
    logger.error(f"Unhandled error: {e}")
    return create_response(500, {"message": "Internal server error"})
```

## Testing

Functions can be tested using:
- AWS Lambda console
- AWS CLI
- CDK testing framework
- Direct API Gateway calls 