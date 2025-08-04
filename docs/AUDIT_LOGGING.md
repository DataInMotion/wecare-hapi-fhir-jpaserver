# FHIR Audit Logging

This document describes the comprehensive audit logging system implemented for the HAPI FHIR server.

## Overview

The audit logging system captures all FHIR REST API calls with detailed information including:
- **User Identity**: Username and email from OAuth 2.0 authentication
- **Request Details**: HTTP method, resource type, operation, parameters
- **Response Information**: Status codes, response types, bundle sizes
- **Client Information**: IP address, user agent
- **Timestamps**: Precise timing of requests and responses

## Features

✅ **Comprehensive Logging**: Captures both incoming requests and outgoing responses  
✅ **User Tracking**: Logs authenticated username and email for all API calls  
✅ **Structured Format**: JSON format for easy parsing and analysis  
✅ **Security Focused**: Logs authentication events and access patterns  
✅ **Performance Monitoring**: Tracks response times and bundle sizes  
✅ **Compliance Ready**: Meets healthcare audit trail requirements  

## Configuration

### Interceptor Configuration

The audit logging is implemented via the `AuditLoggingInterceptor` class:

```java
package org.gecko.fhir.jpa.starter.interceptor;

@Component
@Interceptor
public class AuditLoggingInterceptor {
    // Captures all FHIR requests and responses
}
```

### Log Configuration

Configured in `logback.xml`:

```xml
<!-- Audit Log Appender -->
<appender name="AUDIT_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
    <file>/var/log/hapi-fhir/audit.log</file>
    <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
        <fileNamePattern>/var/log/hapi-fhir/audit.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
        <maxFileSize>100MB</maxFileSize>
        <maxHistory>30</maxHistory>
        <totalSizeCap>3GB</totalSizeCap>
    </rollingPolicy>
</appender>

<logger name="audit" level="INFO" additivity="false">
    <appender-ref ref="AUDIT_FILE" />
    <appender-ref ref="AUDIT_CONSOLE" />
</logger>
```

### Docker Volume Mount

The audit logs are persisted via Docker volume mount:

```yaml
volumes:
  - ./logs/audit:/var/log/hapi-fhir
```

## Log Format

### Request Log Entry

```json
{
  "timestamp": "2024-01-15 14:30:25.123",
  "event_type": "FHIR_REQUEST",
  "username": "john.doe",
  "user_email": "john.doe@example.com",
  "method": "GET",
  "resource_type": "Patient",
  "operation": "search-type",
  "request_path": "/fhir/Patient",
  "fhir_server_base": "https://fhir.mi-jn.de/fhir",
  "client_ip": "192.168.1.100",
  "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  "query_parameters": {
    "_count": "20",
    "_pretty": "true",
    "family": "Smith"
  }
}
```

### Response Log Entry

```json
{
  "timestamp": "2024-01-15 14:30:25.456",
  "event_type": "FHIR_RESPONSE",
  "username": "john.doe",
  "user_email": "john.doe@example.com",
  "method": "GET",
  "resource_type": "Patient",
  "operation": "search-type",
  "request_path": "/fhir/Patient",
  "response_code": 200,
  "response_resource_type": "Bundle",
  "bundle_entries_count": 15,
  "bundle_total": 150,
  "client_ip": "192.168.1.100"
}
```

## Log Fields Reference

| Field | Description | Example |
|-------|-------------|---------|
| `timestamp` | ISO timestamp of the event | `"2024-01-15 14:30:25.123"` |
| `event_type` | Type of audit event | `"FHIR_REQUEST"`, `"FHIR_RESPONSE"` |
| `username` | Authenticated user's username | `"john.doe"` |
| `user_email` | Authenticated user's email | `"john.doe@example.com"` |
| `method` | HTTP method | `"GET"`, `"POST"`, `"PUT"`, `"DELETE"` |
| `resource_type` | FHIR resource type | `"Patient"`, `"Observation"`, `"Organization"` |
| `operation` | FHIR operation type | `"search-type"`, `"read"`, `"create"`, `"update"` |
| `request_path` | Full request path | `"/fhir/Patient/123"` |
| `response_code` | HTTP response code | `200`, `201`, `404`, `500` |
| `client_ip` | Client IP address | `"192.168.1.100"` |
| `user_agent` | Client user agent | Browser or API client information |
| `query_parameters` | Request parameters | JSON object with query parameters |

## Log Management

### Log Rotation

- **Daily Rotation**: Logs rotate daily with compressed archives
- **Size Limit**: Individual log files max 100MB
- **Retention**: 30 days of history maintained
- **Total Size Cap**: Maximum 3GB total storage

### Log Location

- **Container Path**: `/var/log/hapi-fhir/audit.log`
- **Host Path**: `./logs/audit/audit.log`
- **Archived Logs**: `./logs/audit/audit.YYYY-MM-DD.*.log.gz`

## Usage Examples

### View Live Audit Logs

```bash
# Pretty printed JSON format
tail -f logs/audit/audit.log | jq .

# Raw format
tail -f logs/audit/audit.log

# Filter by username
grep '"username":"john.doe"' logs/audit/audit.log | jq .

# Filter by resource type
grep '"resource_type":"Patient"' logs/audit/audit.log | jq .
```

### Analyze User Activity

```bash
# Count requests by user
grep '"event_type":"FHIR_REQUEST"' logs/audit/audit.log | \
  jq -r '.username' | sort | uniq -c | sort -nr

# Find failed requests
grep -E '"response_code":(4[0-9]{2}|5[0-9]{2})' logs/audit/audit.log | jq .

# Track specific user's activity
grep '"username":"john.doe"' logs/audit/audit.log | \
  jq -r '[.timestamp, .method, .resource_type, .response_code] | @tsv'
```

### Security Monitoring

```bash
# Monitor for suspicious activity
grep -E '"response_code":(401|403)' logs/audit/audit.log | jq .

# Track API usage patterns
grep '"event_type":"FHIR_REQUEST"' logs/audit/audit.log | \
  jq -r '.resource_type' | sort | uniq -c | sort -nr

# Monitor large data exports
grep '"bundle_entries_count"' logs/audit/audit.log | \
  jq 'select(.bundle_entries_count > 100)'
```

## Testing

Use the provided test script to verify audit logging:

```bash
# Run audit logging test
./scripts/test-audit-logging.sh
```

The test script will:
1. Verify services are running
2. Authenticate with test credentials
3. Make various FHIR API calls
4. Validate audit log entries
5. Check log format and required fields

## Integration with SIEM Systems

The structured JSON format makes it easy to integrate with SIEM systems:

### Splunk Integration

```splunk
index=fhir_audit source="/var/log/hapi-fhir/audit.log" | 
eval user=username, action=method, resource=resource_type |
stats count by user, action, resource
```

### ELK Stack Integration

```json
{
  "filebeat": {
    "inputs": [{
      "type": "log",
      "paths": ["/var/log/hapi-fhir/audit.log"],
      "json.keys_under_root": true,
      "json.add_error_key": true
    }]
  }
}
```

## Compliance Features

### HIPAA Compliance

- ✅ **Access Logging**: All PHI access is logged with user identity
- ✅ **Audit Trail**: Complete trail of all system interactions
- ✅ **Data Integrity**: Tamper-evident log storage
- ✅ **User Accountability**: Individual user tracking

### GDPR Compliance

- ✅ **Access Tracking**: Log who accessed what personal data
- ✅ **Data Export Monitoring**: Track bulk data exports
- ✅ **User Rights**: Support for data access auditing

## Security Considerations

- **Log Protection**: Ensure audit logs are write-protected and backed up
- **Access Control**: Restrict access to audit logs to authorized personnel
- **Tamper Detection**: Monitor for unauthorized log modifications
- **Retention Policy**: Define appropriate log retention periods

## Troubleshooting

### No Audit Entries

1. Check if the interceptor is loaded:
   ```bash
   docker compose logs hapi-fhir | grep -i audit
   ```

2. Verify log directory permissions:
   ```bash
   ls -la logs/audit/
   ```

3. Check Docker volume mount:
   ```bash
   docker compose exec hapi-fhir ls -la /var/log/hapi-fhir/
   ```

### Missing User Information

1. Verify nginx passes authentication headers:
   ```bash
   docker compose logs nginx | grep -i "x-user\|x-email"
   ```

2. Check oauth2-proxy configuration:
   ```bash
   docker compose logs oauth2-proxy | grep -i "setting header"
   ```

### Performance Impact

The audit logging is designed for minimal performance impact:
- **Asynchronous Logging**: Non-blocking log writes
- **Efficient JSON Serialization**: Optimized for performance
- **Error Isolation**: Logging errors don't break FHIR requests

For high-volume deployments, consider:
- Using dedicated audit log storage
- Implementing log buffering
- Setting up log forwarding to external systems