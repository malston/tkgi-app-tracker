# Microsoft Teams Webhook Setup Guide

This guide explains how to configure Microsoft Teams webhooks for TKGI Application Tracker pipeline notifications.

## Overview

The TKGI Application Tracker uses Microsoft Teams webhooks to send real-time notifications about pipeline execution status, including success alerts, failure notifications, and report availability announcements.

## Prerequisites

- Microsoft Teams access with permissions to add connectors to a channel
- Access to pipeline parameter files or environment variables
- Teams channel dedicated to pipeline notifications (recommended)

## Step 1: Create Teams Webhook

### 1.1 Access Channel Connectors

1. Navigate to the Microsoft Teams channel where you want notifications
2. Click the **three dots (...)** menu next to the channel name
3. Select **"Connectors"** from the dropdown menu

### 1.2 Configure Incoming Webhook

1. Search for **"Incoming Webhook"** in the connectors list
2. Click **"Add"** or **"Configure"** next to Incoming Webhook
3. Provide a name for your webhook (e.g., "TKGI App Tracker Notifications")
4. Optionally upload an image/icon for the webhook
5. Click **"Create"**

### 1.3 Copy Webhook URL

1. After creation, you'll receive a webhook URL
2. **Copy this URL** - it will look like:

   ```
   https://outlook.office.com/webhook/a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6@q7r8s9t0-u1v2-w3x4-y5z6-a7b8c9d0e1f2/IncomingWebhook/g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8/w9x0y1z2-a3b4-c5d6-e7f8-g9h0i1j2k3l4
   ```

3. **Save this URL securely** - anyone with this URL can post to your channel

## Step 2: Configure Pipeline Parameters

### Option A: Parameter File Configuration

Add the webhook URL to your datacenter-specific parameter file:

**File:** `~/git/params/{datacenter}/{datacenter}-k8s-tkgi-app-tracker.yml`

```yaml
# Teams Notification Configuration
teams_webhook_url: "https://outlook.office.com/webhook/YOUR-WEBHOOK-URL-HERE"

# Optional: Configure notification preferences
notification_settings:
  enable_success_notifications: true
  enable_failure_notifications: true
  enable_weekly_summary: true
```

**Examples:**

- `~/git/params/dc01/dc01-k8s-tkgi-app-tracker.yml`
- `~/git/params/dc02/dc02-k8s-tkgi-app-tracker.yml`
- `~/git/params/dc03/dc03-k8s-tkgi-app-tracker.yml`

### Option B: Environment Variable Configuration

For local testing or development:

```bash
export TEAMS_WEBHOOK_URL="https://outlook.office.com/webhook/YOUR-WEBHOOK-URL-HERE"
```

### Option C: Vault/CredHub Integration

For production environments, store the webhook URL in Vault or CredHub:

```yaml
# In parameter file
teams_webhook_url: ((teams-webhook-url))
```

## Step 3: Test Webhook Configuration

### 3.1 Local Testing

Test the webhook configuration using the local execution scripts:

```bash
# Test success notification
MESSAGE="Test success notification from TKGI App Tracker" \
NOTIFICATION_TYPE="success" \
FOUNDATION="dc01-k8s-n-01" \
TEAMS_WEBHOOK_URL="your-webhook-url" \
./scripts/run-pipeline-task.sh notify

# Test failure notification
MESSAGE="Test failure alert from TKGI App Tracker" \
NOTIFICATION_TYPE="failure" \
FOUNDATION="dc01-k8s-n-01" \
TEAMS_WEBHOOK_URL="your-webhook-url" \
./scripts/run-pipeline-task.sh notify

# Test info notification
MESSAGE="Pipeline configuration test" \
NOTIFICATION_TYPE="info" \
FOUNDATION="dc01-k8s-n-01" \
TEAMS_WEBHOOK_URL="your-webhook-url" \
./scripts/run-pipeline-task.sh notify
```

### 3.2 Pipeline Testing

Trigger the pipeline manually to test notifications:

```bash
# Deploy pipeline with webhook configuration
./ci/fly.sh set -f dc01-k8s-n-01

# Trigger manual run
fly -t dc01-k8s-n-01 trigger-job -j tkgi-app-tracker-dc01-k8s-n-01/collect-and-report

# Watch for notifications in Teams channel
```

## Step 4: Notification Message Format

The TKGI Application Tracker sends rich formatted messages to Teams using the MessageCard format.

### Success Notification Example

```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "summary": "TKGI App Tracker - Success",
  "themeColor": "good",
  "sections": [{
    "activityTitle": "✅ TKGI App Tracker - Success",
    "activitySubtitle": "Foundation: dc01-k8s-n-01",
    "activityImage": "https://docs.microsoft.com/en-us/azure/devops/_img/index/devopsicon-teams.png",
    "facts": [
      {
        "name": "Foundation",
        "value": "dc01-k8s-n-01"
      },
      {
        "name": "Timestamp",
        "value": "2024-01-15 10:30:00 UTC"
      },
      {
        "name": "Pipeline",
        "value": "tkgi-app-tracker-dc01-k8s-n-01"
      }
    ],
    "text": "TKGI Application Tracker reports generated successfully for foundation **dc01-k8s-n-01**. Reports available in S3."
  }]
}
```

### Failure Notification Example

```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "summary": "TKGI App Tracker - Failure",
  "themeColor": "attention",
  "sections": [{
    "activityTitle": "❌ TKGI App Tracker - Failure",
    "activitySubtitle": "Foundation: dc02-k8s-n-01",
    "facts": [
      {
        "name": "Foundation",
        "value": "dc02-k8s-n-01"
      },
      {
        "name": "Task",
        "value": "collect-data"
      },
      {
        "name": "Error",
        "value": "Failed to authenticate to TKGI API"
      }
    ],
    "text": "Failed to complete TKGI Application Tracker pipeline for foundation **dc02-k8s-n-01**. Check pipeline logs for details."
  }]
}
```

## Step 5: Notification Types

The pipeline sends different notification types based on events:

### Pipeline Success Notifications

- **Trigger:** Successful completion of all pipeline tasks
- **Content:** Summary statistics, report location, foundation details
- **Color:** Green (`good`)
- **Icon:** ✅

### Pipeline Failure Notifications

- **Trigger:** Any task failure during pipeline execution
- **Content:** Failed task name, error details, troubleshooting guidance
- **Color:** Red (`attention`)
- **Icon:** ❌

### Informational Notifications

- **Trigger:** Manual notifications or status updates
- **Content:** Custom messages, status information
- **Color:** Blue (`#17a2b8`)
- **Icon:** ℹ️

## Step 6: Advanced Configuration

### 6.1 Multiple Channel Support

To send notifications to multiple Teams channels:

```yaml
# In parameter file
primary_teams_webhook_url: "https://outlook.office.com/webhook/CHANNEL-1"
secondary_teams_webhook_url: "https://outlook.office.com/webhook/CHANNEL-2"

# Modify notify task to support multiple webhooks
```

### 6.2 Conditional Notifications

Configure when notifications should be sent:

```yaml
notification_rules:
  send_on_success: true
  send_on_failure: true
  send_weekly_summary: true
  quiet_hours:
    enabled: true
    start: "22:00"
    end: "06:00"
```

### 6.3 Custom Message Templates

Customize notification messages for your organization:

```bash
# In notify/task.sh
CUSTOM_FACTS=$(jq -n \
  --arg build "$BUILD_ID" \
  --arg duration "$TASK_DURATION" \
  --arg cluster_count "$CLUSTER_COUNT" \
  '[
    {"name": "Build", "value": $build},
    {"name": "Duration", "value": $duration},
    {"name": "Clusters Processed", "value": $cluster_count}
  ]')
```

## Step 7: Troubleshooting

### Common Issues and Solutions

#### 1. Webhook Not Receiving Messages

**Symptoms:** Pipeline shows notification sent but no message appears in Teams

**Solutions:**

- Verify webhook URL is correct and complete
- Check Teams channel permissions
- Test webhook with curl command:

```bash
curl -H "Content-Type: application/json" \
     -X POST \
     -d '{"text": "Test message"}' \
     "YOUR-WEBHOOK-URL"
```

#### 2. Authentication Errors (400/401)

**Symptoms:** HTTP 400 or 401 errors when sending notifications

**Solutions:**

- Webhook URL may be expired - recreate webhook in Teams
- Check for special characters in URL that need escaping
- Verify JSON payload is properly formatted

#### 3. Rate Limiting (429)

**Symptoms:** HTTP 429 Too Many Requests errors

**Solutions:**

- Teams webhooks have rate limits (approximately 50 requests per minute)
- Implement exponential backoff in retry logic
- Consider batching notifications

#### 4. Message Not Formatted Correctly

**Symptoms:** Message appears but formatting is broken

**Solutions:**

- Validate JSON structure
- Ensure special characters are escaped
- Test with simplified message first

### Debug Commands

```bash
# Test webhook connectivity
curl -v -X POST "YOUR-WEBHOOK-URL" \
  -H "Content-Type: application/json" \
  -d '{"text": "Connection test"}'

# Validate JSON payload
echo "$PAYLOAD" | jq .

# Check webhook response
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "YOUR-WEBHOOK-URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "Response Body: $BODY"
```

## Step 8: Security Best Practices

### Webhook URL Protection

1. **Never commit webhook URLs to git**
   - Use parameter files with `.gitignore`
   - Use environment variables
   - Use secret management systems

2. **Rotate webhook URLs periodically**
   - Delete and recreate webhooks quarterly
   - Update parameter files accordingly
   - Test after rotation

3. **Limit access to webhook URLs**
   - Store in Vault/CredHub for production
   - Use separate webhooks per environment
   - Monitor webhook usage

### Message Content Security

1. **Avoid sensitive data in notifications**
   - Don't include passwords or secrets
   - Don't include internal URLs or IPs
   - Use generic error messages

2. **Sanitize dynamic content**
   - Escape special characters
   - Validate input data
   - Limit message length

## Additional Resources

### Microsoft Documentation

- **[Official Teams Webhook Documentation](https://docs.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook)**
- **[MessageCard Reference](https://docs.microsoft.com/en-us/outlook/actionable-messages/message-card-reference)**
- **[Teams Connector Best Practices](https://docs.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/connectors-using)**
- **[Adaptive Cards (Modern Alternative)](https://docs.microsoft.com/en-us/microsoftteams/platform/task-modules-and-cards/cards/cards-reference)**

### Pipeline Integration Examples

- **Success Notification:** `ci/tasks/notify/task.sh` (lines 15-30)
- **Failure Handling:** `ci/pipelines/single-foundation-report.yml` (lines 81-87)
- **Local Testing:** `scripts/run-pipeline-task.sh` (lines 265-280)

### Support

For issues with Teams webhook integration:

1. Check this documentation first
2. Review pipeline logs: `fly -t {foundation} watch -j {pipeline}/collect-and-report`
3. Test with local execution scripts
4. Contact Platform Engineering team for assistance

## Appendix: Sample Webhook Payloads

### A. Enhanced Success Notification with Actions

```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "summary": "TKGI App Tracker Reports Ready",
  "themeColor": "good",
  "sections": [{
    "activityTitle": "✅ Weekly Reports Generated Successfully",
    "activitySubtitle": "Foundation: dc01-k8s-n-01",
    "facts": [
      {"name": "Total Namespaces", "value": "157"},
      {"name": "Active Applications", "value": "89"},
      {"name": "Migration Ready", "value": "34"},
      {"name": "Report Size", "value": "2.4 MB"}
    ],
    "text": "Weekly TKGI application tracking reports have been generated and uploaded to S3."
  }],
  "potentialAction": [{
    "@type": "OpenUri",
    "name": "View Reports in S3",
    "targets": [{
      "os": "default",
      "uri": "https://s3.console.aws.amazon.com/s3/buckets/tkgi-app-tracker-reports/"
    }]
  }, {
    "@type": "OpenUri",
    "name": "View Pipeline",
    "targets": [{
      "os": "default",
      "uri": "https://concourse.example.com/teams/dc01-k8s-n-01/pipelines/tkgi-app-tracker-dc01-k8s-n-01"
    }]
  }]
}
```

### B. Detailed Failure Notification

```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "summary": "TKGI App Tracker Pipeline Failed",
  "themeColor": "attention",
  "sections": [{
    "activityTitle": "❌ Pipeline Execution Failed",
    "activitySubtitle": "Immediate attention required",
    "facts": [
      {"name": "Foundation", "value": "dc03-k8s-p-01"},
      {"name": "Failed Task", "value": "collect-data"},
      {"name": "Build Number", "value": "142"},
      {"name": "Duration", "value": "3m 42s"},
      {"name": "Error Code", "value": "AUTH_FAILED"}
    ],
    "text": "**Error Details:**\n\nFailed to authenticate to TKGI API endpoint. The om CLI returned error code 401.\n\n**Troubleshooting Steps:**\n1. Verify Ops Manager credentials in parameter file\n2. Check network connectivity to Ops Manager\n3. Ensure TKGI API service is running\n4. Review build logs for detailed error messages"
  }],
  "potentialAction": [{
    "@type": "OpenUri",
    "name": "View Build Logs",
    "targets": [{
      "os": "default",
      "uri": "https://concourse.example.com/builds/142"
    }]
  }]
}
```

This comprehensive Teams webhook setup guide ensures your team can properly configure, test, and maintain notifications for the TKGI Application Tracker pipeline.
