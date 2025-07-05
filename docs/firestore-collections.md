# LCP Firestore Collections Documentation

## Overview

This document describes the Firestore collections implemented for the LCP (Lead Conversion Pipeline) backend infrastructure. All collections are designed to support the LCP system's requirements for user management, conversation handling, AI/ML operations, and analytics.

## Collection Architecture

### Core Collections

#### 1. Users Collection
**Purpose**: Store user account information and profiles
**Document ID**: `user_id` (UUID)

**Data Model**:
```javascript
{
  user_id: string,
  email: string,
  name: string,
  created_at: timestamp,
  updated_at: timestamp,
  status: string, // 'active', 'inactive', 'suspended'
  organization_id: string,
  role: string, // 'owner', 'admin', 'member', 'viewer'
  preferences: {
    email_notifications: boolean,
    ai_auto_response: boolean,
    response_delay_hours: number,
    max_response_length: number,
    storage_notifications: boolean
  },
  lcp_settings: {
    automatic_enabled: boolean,
    flag_threshold: number, // 0-100
    auto_response_enabled: boolean
  },
  storage_usage: {
    email_storage_mb: number,
    asset_storage_mb: number,
    last_updated: timestamp
  },
  last_login: timestamp,
  last_activity: timestamp
}
```

**Indexes**:
- `email` (ASC) - For email-based lookups
- `organization_id` (ASC) - For organization-based queries
- `status` (ASC) - For active/inactive user filtering
- `created_at` (ASC) - For chronological ordering

#### 2. Organizations Collection
**Purpose**: Store organization information and settings
**Document ID**: `organization_id` (UUID)

**Data Model**:
```javascript
{
  organization_id: string,
  name: string,
  domain: string,
  created_at: timestamp,
  updated_at: timestamp,
  status: string, // 'active', 'inactive', 'suspended'
  settings: {
    email_domain_verification: boolean,
    ai_response_enabled: boolean,
    max_users: number,
    storage_limit_gb: number,
    retention_policy_days: number,
    lcp_automatic_enabled: boolean
  },
  billing: {
    plan: string, // 'basic', 'pro', 'enterprise'
    next_billing_date: timestamp,
    usage: {
      emails_processed: number,
      storage_used_gb: number,
      ai_requests: number,
      active_users: number
    }
  },
  storage_usage: {
    email_storage_gb: number,
    asset_storage_gb: number,
    analytics_storage_gb: number,
    total_storage_gb: number,
    last_updated: timestamp
  }
}
```

**Indexes**:
- `domain` (ASC) - For domain-based lookups
- `status` (ASC) - For active organization filtering
- `created_at` (ASC) - For chronological ordering

#### 3. Conversations Collection
**Purpose**: Store individual email messages within conversations
**Document ID**: `conversation_id` + `message_id` (Composite)

**Data Model**:
```javascript
{
  conversation_id: string,
  message_id: string,
  response_id: string,
  associated_account: string, // user_id
  organization_id: string,
  sender_email: string,
  recipient_email: string,
  subject: string,
  body: string,
  timestamp: timestamp,
  is_first_email: boolean,
  thread_id: string,
  status: string, // 'received', 'processed', 'responded', 'scheduled'
  ai_response: string,
  ev_score: number, // 0-100
  storage_path: string, // Cloud Storage path for attachments
  metadata: {
    headers: object,
    attachments: string[],
    spam_score: number,
    processing_status: string,
    message_size_bytes: number
  },
  created_at: timestamp,
  updated_at: timestamp
}
```

**Indexes**:
- `associated_account` (ASC) - For user-based queries
- `organization_id` (ASC) - For organization-based queries
- `conversation_id` (ASC) - For conversation threading
- `timestamp` (DESC) - For chronological ordering
- `status` (ASC) - For status-based filtering
- `is_first_email` (ASC) - For initial email identification

**Composite Indexes**:
- `org_time` - `organization_id` (ASC) + `timestamp` (DESC)
- `account_time` - `associated_account` (ASC) + `timestamp` (DESC)
- `conv_status` - `conversation_id` (ASC) + `status` (ASC)

#### 4. Threads Collection
**Purpose**: Store thread-level metadata and attributes
**Document ID**: `conversation_id` (UUID)

**Data Model**:
```javascript
{
  conversation_id: string,
  associated_account: string, // user_id
  organization_id: string,
  thread_id: string,
  created_at: timestamp,
  updated_at: timestamp,
  status: string, // 'active', 'closed', 'archived'
  subject: string,
  participants: string[], // email addresses
  message_count: number,
  last_message_at: timestamp,
  read: boolean,
  lcp_enabled: boolean,
  lcp_flag_threshold: number, // 0-100
  flag: boolean,
  flag_for_review: boolean,
  flag_review_override: boolean,
  attributes: {
    urgency: string, // 'high', 'medium', 'low'
    category: string, // 'support', 'sales', 'general'
    priority: number, // 1-10
    sentiment: string, // 'positive', 'neutral', 'negative'
    ai_summary: string,
    budget_range: string,
    preferred_property_types: string,
    timeline: string
  },
  ai_settings: {
    auto_response_enabled: boolean,
    response_delay_hours: number,
    max_response_length: number
  },
  ev_data: {
    current_score: number,
    last_calculated: timestamp,
    confidence_score: number,
    factors: {
      urgency: number,
      priority: number,
      sentiment: number,
      response_time: number
    }
  }
}
```

**Indexes**:
- `associated_account` (ASC) - For user-based queries
- `organization_id` (ASC) - For organization-based queries
- `status` (ASC) - For status-based filtering
- `last_message_at` (DESC) - For recent activity
- `flag_for_review` (ASC) - For flagged threads
- `lcp_enabled` (ASC) - For LCP-enabled threads

**Composite Indexes**:
- `org_status` - `organization_id` (ASC) + `status` (ASC) + `last_message_at` (DESC)
- `account_status` - `associated_account` (ASC) + `status` (ASC) + `last_message_at` (DESC)
- `org_flag` - `organization_id` (ASC) + `flag_for_review` (ASC) + `last_message_at` (DESC)

### Membership & Access Collections

#### 5. OrganizationMembers Collection
**Purpose**: Manage organization membership and roles
**Document ID**: `organization_id` + `user_id` (Composite)

**Data Model**:
```javascript
{
  organization_id: string,
  user_id: string,
  role: string, // 'owner', 'admin', 'member', 'viewer'
  joined_at: timestamp,
  status: string, // 'active', 'inactive', 'pending'
  permissions: {
    manage_users: boolean,
    view_conversations: boolean,
    edit_settings: boolean,
    manage_billing: boolean,
    view_analytics: boolean
  },
  invited_by: string, // user_id
  last_active: timestamp,
  created_at: timestamp,
  updated_at: timestamp
}
```

**Indexes**:
- `user_id` (ASC) - For user-based queries
- `organization_id` (ASC) - For organization-based queries
- `role` (ASC) - For role-based filtering
- `status` (ASC) - For status-based filtering

#### 6. OrganizationInvites Collection
**Purpose**: Manage organization invitations
**Document ID**: `invite_id` (UUID)

**Data Model**:
```javascript
{
  invite_id: string,
  organization_id: string,
  email: string,
  invite_token: string,
  invited_by: string, // user_id
  role: string, // 'member', 'admin'
  status: string, // 'pending', 'accepted', 'expired', 'cancelled'
  expires_at: timestamp,
  accepted_at: timestamp,
  created_at: timestamp,
  updated_at: timestamp
}
```

**Indexes**:
- `email` (ASC) - For email-based lookups
- `invite_token` (ASC) - For token validation
- `organization_id` (ASC) - For organization-based queries
- `status` (ASC) - For status-based filtering
- `expires_at` (ASC) - For expiration tracking

#### 7. Sessions Collection
**Purpose**: Store user session information with automatic expiration
**Document ID**: `session_id` (UUID)
**TTL Field**: `expires_at`

**Data Model**:
```javascript
{
  session_id: string,
  user_id: string,
  organization_id: string,
  created_at: timestamp,
  last_activity: timestamp,
  expires_at: timestamp,
  ip_address: string,
  user_agent: string,
  is_active: boolean,
  metadata: {
    login_method: string, // 'form', 'google', 'sso'
    device_type: string, // 'desktop', 'mobile', 'tablet'
    location: string
  }
}
```

**Indexes**:
- `user_id` (ASC) - For user-based queries
- `organization_id` (ASC) - For organization-based queries
- `is_active` (ASC) - For active session filtering
- `expires_at` (ASC) - For TTL management

### AI/ML Collections

#### 8. RateLimits Collection
**Purpose**: Track rate limits for AI operations and API calls
**Document ID**: `account_id` + `service_type` (Composite)

**Data Model**:
```javascript
{
  account_id: string, // user_id or organization_id
  service_type: string, // 'ai', 'api', 'storage'
  request_count: number,
  window_start: timestamp,
  window_end: timestamp,
  last_request: timestamp,
  limit: number,
  reset_time: timestamp,
  blocked_until: timestamp,
  metadata: {
    function_calls: object,
    service_calls: object,
    cost_usd: number
  },
  created_at: timestamp,
  updated_at: timestamp
}
```

**Indexes**:
- `account_id` (ASC) - For account-based queries
- `service_type` (ASC) - For service-based filtering
- `window_end` (ASC) - For window expiration
- `blocked_until` (ASC) - For blocking status

#### 9. EVData Collection
**Purpose**: Store Expected Value calculation data
**Document ID**: `conversation_id` (UUID)

**Data Model**:
```javascript
{
  conversation_id: string,
  organization_id: string,
  ev_score: number, // 0-100
  calculation_date: timestamp,
  model_used: string,
  factors: {
    urgency: number,
    priority: number,
    sentiment: number,
    response_time: number,
    engagement_level: number
  },
  algorithm_version: string,
  confidence_score: number,
  recommendations: string[],
  storage_path: string, // Path to detailed results in Cloud Storage
  metadata: {
    calculation_time_ms: number,
    data_points_used: number,
    model_confidence: number
  },
  created_at: timestamp,
  updated_at: timestamp
}
```

**Indexes**:
- `organization_id` (ASC) - For organization-based queries
- `calculation_date` (DESC) - For chronological ordering
- `ev_score` (DESC) - For score-based filtering
- `model_used` (ASC) - For model-based analysis

**Composite Indexes**:
- `org_score` - `organization_id` (ASC) + `ev_score` (DESC)
- `org_date` - `organization_id` (ASC) + `calculation_date` (DESC)

#### 10. LLMData Collection
**Purpose**: Store LLM interaction data for analysis
**Document ID**: `conversation_id` + `interaction_id` (Composite)

**Data Model**:
```javascript
{
  conversation_id: string,
  interaction_id: string,
  organization_id: string,
  model_used: string,
  prompt_tokens: number,
  response_tokens: number,
  total_tokens: number,
  response_time_ms: number,
  quality_score: number,
  generated_at: timestamp,
  prompt: string,
  response: string,
  storage_path: string, // Path to full context in Cloud Storage
  metadata: {
    temperature: number,
    top_p: number,
    max_tokens: number,
    cost_usd: number,
    model_version: string,
    function_called: string
  },
  created_at: timestamp
}
```

**Indexes**:
- `conversation_id` (ASC) - For conversation-based queries
- `organization_id` (ASC) - For organization-based queries
- `model_used` (ASC) - For model-based analysis
- `generated_at` (DESC) - For chronological ordering
- `function_called` (ASC) - For function-based analysis

**Composite Indexes**:
- `org_model` - `organization_id` (ASC) + `model_used` (ASC) + `generated_at` (DESC)
- `org_function` - `organization_id` (ASC) + `function_called` (ASC) + `generated_at` (DESC)

### Analytics & Monitoring Collections

#### 11. Reports Collection
**Purpose**: Store aggregated reports and analytics data
**Document ID**: `report_id` (UUID)

**Data Model**:
```javascript
{
  report_id: string,
  organization_id: string,
  report_type: string, // 'llm_usage', 'conversation_analytics', 'user_activity', 'cost_analysis'
  report_period: string, // 'daily', 'weekly', 'monthly', 'yearly'
  period_start: timestamp,
  period_end: timestamp,
  generated_at: timestamp,
  data: {
    total_requests: number,
    total_tokens: number,
    total_cost_usd: number,
    average_response_time_ms: number,
    average_quality_score: number,
    model_usage: object,
    function_breakdown: object,
    conversation_metrics: object,
    user_activity: object
  },
  storage_path: string, // Path to detailed report in Cloud Storage
  created_at: timestamp
}
```

**Indexes**:
- `organization_id` (ASC) - For organization-based queries
- `report_type` (ASC) - For report type filtering
- `report_period` (ASC) - For period-based filtering
- `period_start` (DESC) - For chronological ordering
- `generated_at` (DESC) - For generation time ordering

**Composite Indexes**:
- `org_type` - `organization_id` (ASC) + `report_type` (ASC) + `generated_at` (DESC)
- `org_period` - `organization_id` (ASC) + `report_period` (ASC) + `period_start` (DESC)

#### 12. Invocations Collection
**Purpose**: Track Cloud Function invocations for monitoring
**Document ID**: `invocation_id` (UUID)

**Data Model**:
```javascript
{
  invocation_id: string,
  organization_id: string,
  function_name: string,
  invoked_at: timestamp,
  duration_ms: number,
  memory_used_mb: number,
  status: string, // 'success', 'error', 'timeout'
  error_message: string,
  request_id: string,
  cold_start: boolean,
  metadata: {
    http_method: string,
    endpoint: string,
    user_agent: string,
    ip_address: string
  },
  created_at: timestamp
}
```

**Indexes**:
- `organization_id` (ASC) - For organization-based queries
- `function_name` (ASC) - For function-based analysis
- `invoked_at` (DESC) - For chronological ordering
- `status` (ASC) - For status-based filtering
- `cold_start` (ASC) - For performance analysis

**Composite Indexes**:
- `org_function` - `organization_id` (ASC) + `function_name` (ASC) + `invoked_at` (DESC)
- `org_status` - `organization_id` (ASC) + `status` (ASC) + `invoked_at` (DESC)

## Security Rules

### Organization-Based Access Control
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data and organization data
    match /users/{userId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == userId || 
         resource.data.organization_id == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.organization_id);
    }
    
    // Organization members can access organization data
    match /organizations/{orgId} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.organization_id == orgId;
    }
    
    // Conversations are organization-scoped
    match /conversations/{docId} {
      allow read, write: if request.auth != null && 
        resource.data.organization_id == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.organization_id;
    }
    
    // Threads are organization-scoped
    match /threads/{threadId} {
      allow read, write: if request.auth != null && 
        resource.data.organization_id == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.organization_id;
    }
  }
}
```

## Query Patterns

### Common Queries

#### User Management
```javascript
// Get user by email
db.collection('users').where('email', '==', 'user@example.com').get()

// Get users by organization
db.collection('users').where('organization_id', '==', 'org-id').get()

// Get active users
db.collection('users').where('status', '==', 'active').get()
```

#### Conversation Management
```javascript
// Get conversations for a user
db.collection('conversations')
  .where('associated_account', '==', 'user-id')
  .orderBy('timestamp', 'desc')
  .get()

// Get conversations for an organization
db.collection('conversations')
  .where('organization_id', '==', 'org-id')
  .orderBy('timestamp', 'desc')
  .get()

// Get first emails only
db.collection('conversations')
  .where('is_first_email', '==', true)
  .where('organization_id', '==', 'org-id')
  .get()
```

#### Thread Management
```javascript
// Get active threads for organization
db.collection('threads')
  .where('organization_id', '==', 'org-id')
  .where('status', '==', 'active')
  .orderBy('last_message_at', 'desc')
  .get()

// Get flagged threads for review
db.collection('threads')
  .where('organization_id', '==', 'org-id')
  .where('flag_for_review', '==', true)
  .orderBy('last_message_at', 'desc')
  .get()
```

#### AI/ML Data
```javascript
// Get EV scores for organization
db.collection('ev_data')
  .where('organization_id', '==', 'org-id')
  .orderBy('calculation_date', 'desc')
  .get()

// Get LLM usage by model
db.collection('llm_data')
  .where('organization_id', '==', 'org-id')
  .where('model_used', '==', 'gemini-1.5-pro')
  .orderBy('generated_at', 'desc')
  .get()
```

## Performance Optimization

### Index Strategy
- **Single Field Indexes**: For basic filtering and sorting
- **Composite Indexes**: For complex queries with multiple conditions
- **Array Indexes**: For array-based queries (participants, recommendations)
- **TTL Indexes**: For automatic document expiration (sessions)

### Query Optimization
- **Use Indexes**: Always query on indexed fields
- **Limit Results**: Use `limit()` to restrict result sets
- **Pagination**: Use `startAfter()` for large result sets
- **Projection**: Only retrieve needed fields with `select()`

### Cost Optimization
- **Efficient Queries**: Minimize the number of documents read
- **Batch Operations**: Use batch writes for multiple operations
- **Offline Persistence**: Enable offline persistence for mobile apps
- **Caching**: Implement appropriate caching strategies

## Data Migration

### From DynamoDB to Firestore
1. **Schema Mapping**: Map DynamoDB attributes to Firestore fields
2. **Data Transformation**: Convert data types and structures
3. **Index Creation**: Create necessary indexes before data migration
4. **Batch Migration**: Use batch operations for efficient migration
5. **Validation**: Verify data integrity after migration

### Migration Scripts
```javascript
// Example migration script
const migrateUser = async (dynamoUser) => {
  const firestoreUser = {
    user_id: dynamoUser.id,
    email: dynamoUser.email,
    name: dynamoUser.name,
    created_at: new Date(dynamoUser.created_at),
    updated_at: new Date(dynamoUser.updated_at),
    status: dynamoUser.status,
    organization_id: dynamoUser.organization_id,
    role: dynamoUser.role,
    preferences: {
      email_notifications: dynamoUser.preferences?.email_notifications || true,
      ai_auto_response: dynamoUser.preferences?.ai_auto_response || true
    }
  };
  
  await db.collection('users').doc(dynamoUser.id).set(firestoreUser);
};
```

## Monitoring and Maintenance

### Health Checks
- **Index Status**: Monitor index build status and performance
- **Query Performance**: Track slow queries and optimize
- **Storage Usage**: Monitor collection sizes and growth
- **Error Rates**: Track failed operations and errors

### Backup and Recovery
- **Automatic Backups**: Firestore provides automatic backups
- **Point-in-Time Recovery**: Available for disaster recovery
- **Export/Import**: Use Firestore export/import for data migration
- **Cross-Region Replication**: Available for global distribution

### Best Practices
- **Data Modeling**: Design collections for efficient queries
- **Security**: Implement proper security rules
- **Monitoring**: Set up alerts for performance issues
- **Documentation**: Keep collection schemas documented
- **Testing**: Test queries and security rules thoroughly

## Conclusion

This Firestore collection architecture provides a comprehensive foundation for the LCP backend, supporting all the requirements for user management, conversation handling, AI/ML operations, and analytics. The design prioritizes performance, security, and scalability while maintaining compatibility with the existing AWS DynamoDB structure. 