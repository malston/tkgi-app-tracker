# Application Inactivity Detection

## Overview

This document describes how the TKGI Application Tracker determines whether an application is active or inactive. This classification is crucial for identifying candidates for migration, decommissioning, or further investigation.

## Current Implementation

### Data Collection Phase

During the cluster data collection (`collect-tkgi-cluster-data.sh`), the system captures the **last activity** timestamp for each namespace:

```bash
# Get last pod creation/restart time (indicates activity)
last_activity=$(kubectl get pods -n "$ns" -o json | \
  jq -r '[.items[].status.startTime] | max // "unknown"')
```

**What is captured:**

- The most recent `startTime` across all pods in the namespace
- This represents when the newest pod was created or restarted
- If no pods exist or the data cannot be determined, it's set to "unknown"

### Aggregation Phase

During data aggregation (`aggregate-data.py`), the system determines if an application is active or inactive:

```python
# Determine if app is active (has activity in last 30 days)
if app['last_activity']:
    last_activity_date = datetime.fromisoformat(app['last_activity'].replace('Z', '+00:00'))
    days_since_activity = (datetime.now(last_activity_date.tzinfo) - last_activity_date).days
    app['is_active'] = days_since_activity <= 30
    app['days_since_activity'] = days_since_activity
```

## Activity Classification

### Active Applications

An application is considered **ACTIVE** if:

- It has at least one pod that was started or restarted within the last **30 days**
- The 30-day window is measured from the current date

### Inactive Applications

An application is considered **INACTIVE** if:

- No pods have been started or restarted in the last **30 days**
- OR the namespace has no pods at all (`pod_count = 0`)
- OR the `last_activity` timestamp cannot be determined

### Inactivity Tiers

The system also tracks `days_since_activity` which enables classification into tiers:

| Tier | Days Since Activity | Migration Readiness Bonus | Interpretation |
|------|-------------------|---------------------------|----------------|
| **Recently Active** | 0-30 days | 0 points | Application in regular use |
| **Recently Inactive** | 31-60 days | +10 points | Reduced activity, possible candidate |
| **Long-term Inactive** | 61+ days | +20 points | Likely abandoned or unused |

## Limitations of Current Approach

### What IS Detected

- Pod restarts (planned or unplanned)
- New deployments
- Scaling events that create new pods
- CronJob executions that spawn pods

### What IS NOT Detected

- **Application-level activity**: API calls, database transactions, message processing
- **Network traffic**: Incoming requests, service-to-service communication
- **Resource utilization**: CPU/memory usage patterns
- **Configuration changes**: ConfigMap or Secret updates that don't trigger pod restarts
- **Log activity**: Application logs indicating processing
- **User interactions**: Actual business usage of the application

### Edge Cases

1. **Long-running pods**: Applications with stable pods that never restart may appear inactive
2. **Batch jobs**: Applications that run periodically might be missed if outside the 30-day window
3. **Stateful applications**: Databases or caches that run continuously without restarts
4. **Event-driven apps**: Applications that process events but have stable pods

## Data Quality Indicators

The system tracks data quality for inactive applications:

```python
if app['last_activity'] == 'unknown':
    app['data_quality'] = 'incomplete'
```

Applications with `data_quality = 'incomplete'` require manual investigation.

## Using Inactivity Data

### In Reports

- **Executive Summary**: Shows total active vs inactive counts
- **Migration Planning**: Inactive apps get higher migration readiness scores
- **Foundation Analysis**: Breakdown of inactive apps per foundation
- **Trend Analysis**: Track changes in activity patterns over time

### Decision Making

Use inactivity status to:

1. **Prioritize migrations**: Start with long-term inactive applications
2. **Identify cleanup candidates**: Applications with no activity for 90+ days
3. **Resource optimization**: Reclaim resources from inactive namespaces
4. **Cost reduction**: Identify underutilized clusters with many inactive apps

## Future Enhancements

### Potential Improvements

1. **Deployment history**: Check `kubectl rollout history` for recent updates
2. **Service metrics**: Integrate with Istio/Prometheus for traffic metrics
3. **Event analysis**: Analyze Kubernetes events for activity indicators
4. **Custom metrics**: Support application-specific activity endpoints
5. **Configurable thresholds**: Make the 30-day window configurable
6. **Multiple activity sources**: Combine multiple signals for accuracy

### Recommended Additional Checks

```bash
# Check deployment update times
kubectl get deployments -n $ns -o json | \
  jq -r '[.items[].metadata.annotations["deployment.kubernetes.io/revision-change-time"]] | max'

# Check recent events
kubectl get events -n $ns --sort-by='.lastTimestamp' | tail -1

# Check service endpoints (if receiving traffic)
kubectl get endpoints -n $ns -o json | \
  jq '.items[].subsets[].addresses | length'
```

## Configuration

Currently, the 30-day threshold is hardcoded. To modify:

1. Edit `scripts/aggregate-data.py` line ~111:

   ```python
   app['is_active'] = days_since_activity <= 30  # Change 30 to desired threshold
   ```

2. Update migration readiness scoring thresholds (lines ~167-171):

   ```python
   if days_inactive and days_inactive > 60:  # Long-term inactive
       score += 20
   elif days_inactive and days_inactive > 30:  # Recently inactive
       score += 10
   ```

## Best Practices

1. **Regular Collection**: Run data collection daily to maintain accurate activity tracking
2. **Manual Verification**: For production applications showing as inactive, verify with application teams
3. **Combine with Other Metrics**: Don't rely solely on pod start times for critical decisions
4. **Historical Tracking**: Keep historical data to identify activity patterns
5. **Alert on Changes**: Monitor applications transitioning from active to inactive

## Troubleshooting

### Application Shows as Inactive but Is Actually Active

**Possible causes:**

- Pods have been running stable for >30 days
- Application uses external triggers not creating pods
- Data collection missed recent activity

**Resolution:**

- Check deployment history: `kubectl rollout history deployment -n <namespace>`
- Review application logs for recent activity
- Verify with application team

### Unable to Determine Activity (last_activity = "unknown")

**Possible causes:**

- Namespace has no pods
- Permission issues accessing pod data
- Malformed pod status data

**Resolution:**

- Verify namespace has deployed resources: `kubectl get all -n <namespace>`
- Check RBAC permissions for service account
- Manually inspect pod data: `kubectl get pods -n <namespace> -o yaml`

## Related Documentation

- [Migration Readiness Guide](./migration-readiness-guide.md) - How inactivity affects migration scoring
- [Pipeline Architecture](./pipeline-architecture.md) - Overall data flow
- [Excel Report Guide](./excel-report-guide.md) - Using inactivity data in reports
