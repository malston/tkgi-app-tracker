#!/bin/sh

set -e

# Function to determine notification style based on type
get_notification_payload() {
  local message="$1"
  local type="${2:-info}"
  local color
  local icon
  local title

  case "$type" in
    success)
      color="Good"
      icon="✅"
      title="Success"
      ;;
    error|failure)
      color="Attention"
      icon="❌"
      title="Error"
      ;;
    warning|warn)
      color="Warning"
      icon="⚠️"
      title="Warning"
      ;;
    info)
      color="Accent"
      icon="ℹ️"
      title="Information"
      ;;
    *)
      color="Accent"
      icon="📢"
      title="Notification"
      ;;
  esac

  # Create Teams message card format
  cat <<EOF
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "content": {
        "type": "AdaptiveCard",
        "version": "1.0",
        "body": [
          {
            "type": "TextBlock",
            "text": "${icon} ${title}",
            "weight": "Bolder",
            "size": "Medium"
          },
          {
            "type": "TextBlock",
            "text": "${message}",
            "wrap": true
          },
          {
            "type": "FactSet",
            "facts": [
              {
                "title": "Pipeline:",
                "value": "TKGI Application Tracker"
              },
              {
                "title": "Time:",
                "value": "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
              }
            ]
          }
        ],
        "msteams": {
          "width": "Full"
        }
      }
    }
  ]
}
EOF
}

# Send notification to Teams webhook
if [ -n "${WEBHOOK_URL}" ]; then
  echo "Sending ${NOTIFICATION_TYPE:-info} notification: ${MESSAGE}"

  payload=$(get_notification_payload "${MESSAGE}" "${NOTIFICATION_TYPE}")

  if curl -s -H 'Content-Type: application/json' \
          -d "${payload}" \
          "${WEBHOOK_URL}" > /dev/null; then
    echo "Notification sent successfully"
  else
    echo "Failed to send notification, trying simple format..."
    # Fallback to simple text format
    simple_payload="{\"text\": \"${MESSAGE}\"}"
    if curl -s -H 'Content-Type: application/json' \
            -d "${simple_payload}" \
            "${WEBHOOK_URL}" > /dev/null; then
      echo "Simple notification sent successfully"
    else
      echo "Error: Failed to send notification" >&2
      exit 1
    fi
  fi
else
  echo "No webhook URL configured, skipping notification"
fi
