# Cognito User Pools Documentation

## Overview

The ACS infrastructure uses Amazon Cognito User Pools for user authentication and management. The system supports both form-based authentication and Google OAuth integration, with comprehensive user management features and security configurations.

## User Pool Configuration

### Basic Settings
- **User Pool Name**: `acsd2p-{stage}-UserPool`
- **User Pool Client Name**: `acsd2p-{stage}-UserPoolClient`
- **Self Sign-Up**: Enabled
- **Sign-In Aliases**: Email only
- **MFA**: Optional (can be enabled per user)
- **Removal Policy**: RETAIN (data preserved during deployments)

### Configuration Details
```typescript
{
  userPoolName: getResourceName(props.stage, 'UserPool'),
  selfSignUpEnabled: true,
  signInAliases: { email: true },
  standardAttributes: {
    email: { required: true, mutable: true },
  },
  passwordPolicy: {
    minLength: 8,
    requireLowercase: true,
    requireUppercase: true,
    requireDigits: true,
    requireSymbols: true,
  },
  accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
  removalPolicy: cdk.RemovalPolicy.RETAIN,
}
```

## User Pool Client Configuration

### OAuth Settings
```typescript
{
  userPool: userPool,
  userPoolClientName: getResourceName(props.stage, 'UserPoolClient'),
  generateSecret: true,
  authFlows: {
    adminUserPassword: true,
    userPassword: true,
    userSrp: true,
  },
  oAuth: {
    flows: {
      authorizationCodeGrant: true,
      implicitCodeGrant: true,
    },
    scopes: [
      cognito.OAuthScope.EMAIL,
      cognito.OAuthScope.OPENID,
      cognito.OAuthScope.PROFILE
    ],
    callbackUrls: [
      'http://localhost:3000/callback',
      'https://yourdomain.com/callback'
    ],
  },
}
```

## Authentication Flows

### 1. Form-Based Authentication
- **Flow Type**: Username/Password authentication
- **User Registration**: Self-service sign-up
- **Email Verification**: Required for new accounts
- **Password Requirements**: 
  - Minimum 8 characters
  - Must contain lowercase, uppercase, digits, and symbols

#### Registration Process
1. **User Sign-Up**: User provides email and password
2. **Email Verification**: Verification code sent to email
3. **Account Activation**: User enters verification code
4. **Profile Creation**: User completes profile setup

#### Login Process
1. **Credential Entry**: User enters email and password
2. **Authentication**: Cognito validates credentials
3. **Session Creation**: JWT tokens generated
4. **Access Granted**: User redirected to application

### 2. Google OAuth Authentication
- **Flow Type**: OAuth 2.0 with Google
- **Integration**: Google Identity Provider
- **Scopes**: Email, profile, openid
- **Token Handling**: JWT tokens for session management

#### OAuth Flow
1. **User Initiation**: User clicks "Sign in with Google"
2. **Google Authorization**: User authorizes on Google
3. **Callback Processing**: Google redirects with authorization code
4. **Token Exchange**: Exchange code for access token
5. **User Creation**: Create or link Cognito user
6. **Session Establishment**: Generate Cognito tokens

## User Management

### User Attributes
- **Standard Attributes**:
  - `email` (required, mutable)
  - `email_verified` (auto-managed)
  - `sub` (unique identifier)
  - `created_at` (auto-managed)
  - `updated_at` (auto-managed)

- **Custom Attributes**:
  - `organization_id` (string)
  - `user_role` (string)
  - `preferences` (string, JSON)
  - `account_status` (string)

### User States
- **FORCE_CHANGE_PASSWORD**: User must change password
- **CONFIRMED**: User account is active
- **UNCONFIRMED**: User hasn't verified email
- **ARCHIVED**: User account archived
- **COMPROMISED**: Account security compromised
- **UNKNOWN**: Unknown state

### User Operations
- **Create User**: Admin or self-service creation
- **Update User**: Modify user attributes
- **Delete User**: Soft or hard delete
- **Disable User**: Temporarily disable account
- **Enable User**: Re-enable disabled account

## Security Configuration

### Password Policy
```json
{
  "minimumLength": 8,
  "requireUppercase": true,
  "requireLowercase": true,
  "requireNumbers": true,
  "requireSymbols": true,
  "temporaryPasswordValidityDays": 7
}
```

### Account Recovery
- **Recovery Method**: Email only
- **Recovery Flow**: 
  1. User requests password reset
  2. Verification code sent to email
  3. User enters new password with code
  4. Password updated and user signed in

### Multi-Factor Authentication (MFA)
- **MFA Type**: Optional (SMS or TOTP)
- **SMS Configuration**: Requires phone number
- **TOTP Configuration**: Requires authenticator app
- **MFA Setup**: User can enable/disable MFA

### Advanced Security Features
- **Risk-Based Adaptive Authentication**: 
  - Device fingerprinting
  - Location-based risk assessment
  - Behavioral analysis
- **Compromised Credential Detection**:
  - Password breach detection
  - Suspicious activity monitoring
- **Account Takeover Protection**:
  - Unusual sign-in detection
  - Challenge-based verification

## Integration with Application

### Lambda Triggers
- **Pre-Authentication**: Custom validation logic
- **Pre-Sign-Up**: User validation before registration
- **Post-Authentication**: Post-login processing
- **Post-Confirmation**: Post-email verification
- **Pre-Token Generation**: Token customization
- **User Migration**: Legacy user migration

### API Integration
- **Authentication Endpoints**:
  - `/api/auth/login` - User authentication
  - `/api/auth/authorize` - Token validation
  - `/api/session/create` - Session management

### Session Management
- **Token Types**:
  - Access Token (short-lived)
  - ID Token (user identity)
  - Refresh Token (long-lived)
- **Token Expiration**:
  - Access Token: 1 hour
  - ID Token: 1 hour
  - Refresh Token: 30 days

## Monitoring and Analytics

### CloudWatch Metrics
- **SignInSuccesses**: Successful sign-ins
- **SignInFailures**: Failed sign-in attempts
- **SignUpSuccesses**: Successful registrations
- **SignUpFailures**: Failed registration attempts
- **TokenRefreshSuccesses**: Successful token refreshes
- **TokenRefreshFailures**: Failed token refreshes

### User Analytics
- **Active Users**: Daily/monthly active users
- **Registration Rate**: New user sign-ups
- **Authentication Success Rate**: Login success percentage
- **MFA Adoption**: Users with MFA enabled
- **Password Reset Rate**: Password reset frequency

### Security Monitoring
- **Failed Authentication Attempts**: Monitor for brute force attacks
- **Unusual Sign-In Patterns**: Detect suspicious activity
- **Account Compromise Indicators**: Monitor for compromised accounts
- **Geographic Access Patterns**: Track sign-in locations

## Compliance and Governance

### Data Protection
- **Encryption**: All data encrypted at rest and in transit
- **Data Retention**: Configurable retention policies
- **Data Deletion**: Secure data deletion procedures
- **Privacy Controls**: GDPR and CCPA compliance

### Audit and Compliance
- **Access Logging**: All authentication events logged
- **User Activity Tracking**: Complete user activity audit trail
- **Compliance Reports**: Automated compliance reporting
- **Data Export**: User data export capabilities

### Security Standards
- **SOC 2**: Security and availability controls
- **ISO 27001**: Information security management
- **GDPR**: European data protection compliance
- **CCPA**: California privacy compliance

## Best Practices

### Security Best Practices
- **Strong Password Policy**: Enforce complex passwords
- **MFA Enforcement**: Require MFA for sensitive operations
- **Session Management**: Implement proper session handling
- **Regular Security Reviews**: Conduct security assessments

### User Experience Best Practices
- **Clear Error Messages**: Provide helpful error feedback
- **Progressive Registration**: Step-by-step sign-up process
- **Password Reset Flow**: Simple password recovery
- **Account Recovery**: Multiple recovery options

### Integration Best Practices
- **Token Validation**: Always validate tokens server-side
- **Error Handling**: Implement comprehensive error handling
- **Rate Limiting**: Prevent abuse through rate limiting
- **Monitoring**: Monitor authentication metrics

## Troubleshooting

### Common Issues

#### Authentication Failures
- **Invalid Credentials**: Check username/password
- **Account Locked**: Account may be disabled
- **Email Not Verified**: User needs to verify email
- **MFA Issues**: MFA configuration problems

#### Registration Issues
- **Email Already Exists**: User already registered
- **Invalid Email Format**: Email format validation
- **Password Policy**: Password doesn't meet requirements
- **Verification Code**: Invalid or expired code

#### Token Issues
- **Expired Tokens**: Tokens past expiration
- **Invalid Tokens**: Malformed or tampered tokens
- **Refresh Token Issues**: Refresh token problems
- **Scope Issues**: Insufficient permissions

### Debugging Tools
- **CloudWatch Logs**: Authentication event logs
- **Cognito Console**: User pool management interface
- **AWS CLI**: Command-line management
- **SDK Debugging**: Client-side debugging tools

## Cost Optimization

### Pricing Model
- **Monthly Active Users**: Charges per MAU
- **Storage**: User data storage costs
- **SMS**: MFA SMS charges
- **Advanced Security**: Additional security feature costs

### Cost Monitoring
- **Usage Tracking**: Monitor user activity
- **Cost Alerts**: Set up cost thresholds
- **Optimization**: Optimize user management
- **Cleanup**: Remove inactive users

### Optimization Strategies
- **User Cleanup**: Remove inactive accounts
- **MFA Optimization**: Use TOTP instead of SMS
- **Storage Optimization**: Minimize custom attributes
- **Feature Usage**: Disable unused features 