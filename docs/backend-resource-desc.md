# ACS Lead Conversion Pipeline - GCP Backend Infrastructure Plan

## Executive Summary

This plan outlines a modern, scalable, and secure backend infrastructure for the ACS Lead Conversion Pipeline on Google Cloud Platform. The architecture leverages GCP's native services to create a more efficient, secure, and robust system compared to the current AWS implementation.

## Current State Analysis

### AWS Infrastructure (Old)
- **30+ Lambda Functions** handling various LCP operations
- **DynamoDB** with 13 tables for data storage
- **SQS/SNS** for message queuing and email processing
- **SES** for email sending/receiving
- **Cognito** for authentication
- **S3** for file storage
- **API Gateway** for REST endpoints

### Key LCP Components Identified
1. **EV Scoring System** - 12 LLMs analyzing engagement value (0-100)
2. **Thread Management** - Email conversation threading and metadata
3. **AI Response Generation** - Automated email responses
4. **Rate Limiting** - Per-account AI and API rate limits
5. **Email Processing Pipeline** - End-to-end email handling
6. **User/Organization Management** - Multi-tenant architecture
7. Email Processing and Handling (Processing and Responding to Incoming Emails)

## GCP Target Architecture

### High-Level Architecture Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Cloud Run     │    │   Cloud         │
│   (Next.js)     │◄──►│   (API Layer)   │◄──►│   Functions     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Identity      │    │   Firestore     │    │   Cloud         │
│   Platform      │    │   (Database)    │    │   Storage       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Pub/Sub       │    │   Vertex AI     │    │   Cloud         │
│   (Queuing)     │◄──►│   (AI/ML)       │◄──►│   KMS           │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Core Infrastructure Components

### 1. Compute Layer

#### Cloud Run (Primary API Layer)
- **Purpose**: Replace API Gateway + Lambda for HTTP endpoints
- **Benefits**: 
  - Better cold start performance than Lambda
  - Native container support
  - Automatic scaling
  - Built-in load balancing

#### Cloud Functions (Event-Driven Processing)
- **Purpose**: Handle Pub/Sub triggers and background processing


### 2. Data Layer

#### Firestore (Primary Database)
- **Purpose**: Replace DynamoDB with better querying capabilities
- **Collections**:
  ```javascript
  // Core LCP Collections
  conversations: {
    conversation_id: string,
    account_id: string,
    thread_id: string,
    status: string, // 'active', 'completed', 'archived'
    created_at: timestamp,
    updated_at: timestamp,
    ev_score: number, // 0-100
    stage: string, // 'contacted', 'engaged', 'toured', 'offer', 'closed'
    participants: string[],
    message_count: number,
    last_message_at: timestamp,
    metadata: {
      urgency: string,
      category: string,
      priority: number,
      sentiment: string
    }
  }

  messages: {
    message_id: string,
    conversation_id: string,
    account_id: string,
    sender_email: string,
    recipient_email: string,
    subject: string,
    body: string,
    timestamp: timestamp,
    is_first_email: boolean,
    status: string, // 'received', 'processed', 'responded', 'scheduled'
    ai_response: string,
    ev_score: number,
    metadata: {
      headers: object,
      attachments: string[],
      spam_score: number
    }
  }

  users: {
    user_id: string,
    account_id: string,
    email: string,
    name: string,
    role: string,
    created_at: timestamp,
    last_login: timestamp,
    preferences: {
      auto_response_enabled: boolean,
      response_delay_hours: number,
      max_response_length: number
    }
  }

  organizations: {
    organization_id: string,
    name: string,
    domain: string,
    created_at: timestamp,
    status: string,
    settings: {
      email_domain_verification: boolean,
      ai_response_enabled: boolean,
      max_users: number,
      storage_limit_gb: number
    },
    billing: {
      plan: string,
      next_billing_date: timestamp,
      usage: {
        emails_processed: number,
        storage_used_gb: number
      }
    }
  }

  rate_limits: {
    account_id: string,
    request_count: number,
    window_start: timestamp,
    window_end: timestamp,
    last_request: timestamp,
    limit: number,
    reset_time: timestamp,
    blocked_until: timestamp,
    metadata: {
      function_calls: object,
      service_calls: object
    }
  }

  ev_data: {
    conversation_id: string,
    ev_score: number,
    calculation_date: timestamp,
    factors: {
      urgency: number,
      priority: number,
      sentiment: number,
      response_time: number
    },
    algorithm_version: string,
    confidence_score: number,
    recommendations: string[]
  }

  llm_data: {
    conversation_id: string,
    model_used: string,
    prompt_tokens: number,
    response_tokens: number,
    total_tokens: number,
    response_time_ms: number,
    quality_score: number,
    generated_at: timestamp,
    prompt: string,
    response: string,
    metadata: {
      temperature: number,
      top_p: number,
      max_tokens: number,
      cost_usd: number
    }
  }
  ```

#### Cloud Storage (File Storage)
- **Purpose**: Replace S3 for file storage
- **Buckets**:
  - `lcp-email-attachments-{env}` - Email attachments and content
  - `lcp-templates-{env}` - Email templates and signatures
  - `lcp-analytics-{env}` - Analytics data and reports
  - `lcp-backups-{env}` - System backups

### 3. Messaging Layer

#### Pub/Sub (Message Queuing)
- **Purpose**: Replace SQS/SNS for event-driven processing
- **Topics**:
  - `email-received` - New email notifications
  - `email-processed` - Email processing completion
  - `ev-calculation` - EV scoring requests
  - `ai-response` - AI response generation
  - `rate-limit-check` - Rate limiting requests

#### Subscriptions:
  - `email-processor-sub` - Processes new emails
  - `ev-scorer-sub` - Calculates engagement values
  - `ai-response-sub` - Generates AI responses
  - `rate-limiter-sub` - Handles rate limiting

### 4. AI/ML Layer

#### Vertex AI (AI/ML Platform)
- **Purpose**: Replace Together AI with native GCP AI services
- **Services**:
  - **Vertex AI Model Garden** - Access to 12+ LLM models
  - **Custom Models** - Fine-tuned models for LCP
  - **Batch Prediction** - Batch EV scoring
  - **Online Prediction** - Real-time AI responses
  - **Model Monitoring** - AI model performance tracking

#### AI Models for LCP:
```javascript
// EV Scoring Models (12 LLMs)
const evScoringModels = [
  'gemini-1.5-pro',
  'gemini-1.5-flash',
  'claude-3-sonnet',
  'claude-3-haiku',
  'llama-3-70b',
  'llama-3-8b',
  'mistral-7b',
  'mixtral-8x7b',
  'codellama-34b',
  'phi-3-mini',
  'qwen-72b',
  'yi-34b'
];

// Response Generation Models
const responseModels = {
  primary: 'gemini-1.5-pro',
  fast: 'gemini-1.5-flash',
  creative: 'claude-3-sonnet',
  efficient: 'llama-3-8b'
};
```

### 5. Security Layer

#### Identity Platform (Authentication)
- **Purpose**: Replace Cognito with native GCP authentication
- **Features**:
  - Multi-provider authentication (Google, Email/Password)
  - Multi-factor authentication
  - Session management
  - Role-based access control

#### Cloud KMS (Encryption)
- **Purpose**: Centralized key management
- **Keys**:
  - `lcp-data-encryption` - Database encryption
  - `lcp-api-keys` - API key management
  - `lcp-email-signing` - Email signing keys

#### Secret Manager
- **Purpose**: Secure credential storage
- **Secrets**:
  - API keys for external services
  - Database connection strings
  - AI model access tokens
  - Email service credentials

### 6. Monitoring & Observability

#### Cloud Monitoring
- **Custom Metrics**:
  - EV scoring accuracy
  - Response generation latency
  - Email processing throughput
  - User engagement rates
  - Conversion funnel metrics

#### Cloud Logging
- **Structured Logging**:
  - Request/response logs
  - AI model interactions
  - Error tracking
  - Performance metrics

#### Error Reporting
- **Real-time Error Tracking**:
  - Application errors
  - AI model failures
  - Infrastructure issues

## LCP-Specific Infrastructure

### 1. EV Scoring System

#### Architecture:
```javascript
// EV Scoring Pipeline
const evScoringPipeline = {
  input: 'email_message',
  processing: [
    'text_preprocessing',
    'multi_model_scoring', // 12 LLMs
    'score_aggregation',
    'confidence_calculation',
    'stage_assignment'
  ],
  output: {
    ev_score: number, // 0-100
    confidence: number,
    stage: string,
    factors: object,
    recommendations: string[]
  }
};
```

#### Cloud Functions:
- `ev-scorer` - Main EV scoring function
- `ev-aggregator` - Aggregates scores from multiple models
- `ev-validator` - Validates scoring results

### 2. Thread Management System

#### Architecture:
```javascript
// Thread Management
const threadManagement = {
  creation: 'new_email_received',
  processing: [
    'conversation_linking',
    'participant_identification',
    'metadata_extraction',
    'stage_tracking',
    'ai_suggestion_generation'
  ],
  actions: [
    'send_response',
    'schedule_followup',
    'flag_for_review',
    'advance_stage'
  ]
};
```

### 3. AI Response Generation

#### Architecture:
```javascript
// AI Response Pipeline
const aiResponsePipeline = {
  input: 'conversation_context',
  processing: [
    'context_analysis',
    'intent_detection',
    'response_generation',
    'quality_scoring',
    'safety_check'
  ],
  output: {
    response: string,
    confidence: number,
    suggested_actions: string[],
    next_steps: string[]
  }
};
```

## Performance Optimizations

### 1. Caching Strategy
- **Cloud CDN** - Static content delivery
- **Memorystore (Redis)** - Session and data caching
- **Cloud Storage** - CDN for file delivery

### 2. Database Optimization
- **Firestore Indexes** - Optimized queries
- **Batch Operations** - Efficient data operations
- **Connection Pooling** - Optimized connections

### 3. AI Model Optimization
- **Model Caching** - Cache frequently used models
- **Batch Processing** - Process multiple requests together
- **Model Selection** - Choose optimal model per use case

## Security Enhancements

### 1. Data Protection
- **Encryption at Rest** - All data encrypted
- **Encryption in Transit** - TLS 1.3 for all communications
- **Data Classification** - Sensitive data identification
- **Access Controls** - Principle of least privilege

### 2. API Security
- **API Keys** - Secure API access
- **Rate Limiting** - Prevent abuse
- **Input Validation** - Sanitize all inputs
- **CORS Configuration** - Secure cross-origin requests

### 3. Compliance
- **GDPR Compliance** - Data protection regulations
- **SOC 2 Type II** - Security controls
- **ISO 27001** - Information security
- **Regular Audits** - Security assessments

## Scalability Features

### 1. Auto-scaling
- **Cloud Run** - Automatic scaling based on demand
- **Cloud Functions** - Event-driven scaling
- **Firestore** - Automatic scaling for database

### 2. Load Balancing
- **Cloud Load Balancer** - Global load balancing
- **Health Checks** - Automatic failover
- **Traffic Management** - Intelligent routing

### 3. Multi-region Deployment
- **Global Distribution** - Deploy across regions
- **Data Replication** - Cross-region data backup
- **Disaster Recovery** - Business continuity

## Cost Optimization

### 1. Resource Optimization
- **Right-sizing** - Optimize resource allocation
- **Scheduling** - Scale down during off-peak hours
- **Reserved Instances** - Commit to usage for discounts

### 2. AI Cost Management
- **Model Selection** - Choose cost-effective models
- **Batch Processing** - Reduce API calls
- **Caching** - Cache expensive operations

### 3. Storage Optimization
- **Lifecycle Policies** - Automatic data archival
- **Compression** - Reduce storage costs
- **Tiered Storage** - Use appropriate storage classes

## Migration Strategy

### Phase 1: Foundation (Weeks 1-4)
1. Set up GCP project and billing
2. Deploy core infrastructure (VPC, IAM, KMS)
3. Set up monitoring and logging
4. Create development environment

### Phase 2: Data Migration (Weeks 5-8)
1. Set up Firestore and create collections
2. Migrate data from DynamoDB to Firestore
3. Set up data validation and testing
4. Create backup and recovery procedures

### Phase 3: API Migration (Weeks 9-12)
1. Deploy Cloud Run services
2. Migrate Lambda functions to Cloud Functions
3. Set up API Gateway and routing
4. Implement authentication with Identity Platform

### Phase 4: AI/ML Migration (Weeks 13-16)
1. Set up Vertex AI environment
2. Migrate AI models and pipelines
3. Implement EV scoring system
4. Set up AI response generation

### Phase 5: Testing & Optimization (Weeks 17-20)
1. Comprehensive testing
2. Performance optimization
3. Security hardening
4. Documentation and training

### Phase 6: Production Deployment (Weeks 21-24)
1. Production environment setup
2. Gradual traffic migration
3. Monitoring and alerting
4. Go-live and support

## Risk Mitigation

### 1. Data Loss Prevention
- **Backup Strategy** - Multiple backup locations
- **Data Validation** - Verify data integrity
- **Rollback Plan** - Quick recovery procedures

### 2. Performance Risks
- **Load Testing** - Validate performance under load
- **Monitoring** - Real-time performance tracking
- **Optimization** - Continuous performance improvement

### 3. Security Risks
- **Security Testing** - Regular security assessments
- **Access Reviews** - Periodic access audits
- **Incident Response** - Security incident procedures

## Success Metrics

### 1. Performance Metrics
- **Response Time** - < 200ms for API calls
- **Throughput** - 1000+ requests/second
- **Availability** - 99.9% uptime
- **Latency** - < 50ms for AI responses

### 2. Business Metrics
- **EV Scoring Accuracy** - > 90% accuracy
- **Response Quality** - > 85% user satisfaction
- **Conversion Rate** - Improved lead conversion
- **Cost Efficiency** - 30% cost reduction

### 3. Technical Metrics
- **Error Rate** - < 0.1% error rate
- **Security Incidents** - Zero security breaches
- **Compliance** - 100% compliance score
- **Documentation** - Complete technical documentation

## Conclusion

This GCP backend infrastructure plan provides a modern, scalable, and secure foundation for the ACS Lead Conversion Pipeline. The architecture leverages GCP's native services to create a more efficient and robust system compared to the current AWS implementation.

Key improvements include:
- **Better Performance** - Cloud Run provides faster cold starts than Lambda
- **Enhanced Security** - Native GCP security services
- **Improved Scalability** - Automatic scaling and global distribution
- **Cost Optimization** - More efficient resource utilization
- **Better AI Integration** - Native Vertex AI platform
- **Enhanced Monitoring** - Comprehensive observability

The phased migration approach ensures minimal disruption while providing a clear path to a more advanced and efficient LCP system.

