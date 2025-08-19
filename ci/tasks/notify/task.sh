#!/bin/sh

set -e

# Send notification to Teams webhook
if [ -n "${WEBHOOK_URL}" ]; then
  echo "Sending notification: ${MESSAGE}"
  
  curl -H 'Content-Type: application/json' \
       -d "{\"text\": \"${MESSAGE}\"}" \
       "${WEBHOOK_URL}"
  
  echo "Notification sent successfully"
else
  echo "No webhook URL configured, skipping notification"
fi