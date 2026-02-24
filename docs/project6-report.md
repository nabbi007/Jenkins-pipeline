# Project 6 - Full Observability and Security Report

**Project:** CI/CD Voting App with Full Observability and AWS Security Controls  
**Date:** February 23, 2026 (UTC)  
**Region:** eu-west-1

## 1. Scope and Architecture

This implementation extends the existing containerized voting application from the CI/CD project with:

- Metrics-driven monitoring using Prometheus and Grafana
- Alerting for application quality thresholds (error rate and latency)
- AWS security telemetry using CloudWatch Logs, CloudTrail, and GuardDuty
- CloudTrail retention and data protection controls in S3 (encryption + lifecycle)

### Deployed Topology

- **App host (EC2):** `54.78.54.132`
  - Jenkins
  - Frontend container (Nginx)
  - Backend container (Node.js/Express, `/metrics`)
  - Redis container
  - Node Exporter
- **Observability host (EC2):** `108.130.163.21`
  - Prometheus
  - Grafana
  - Node Exporter
  - Loki/Promtail (already present on host)

Infrastructure and security resources are managed in Terraform under `infra/terraform/`.

## 2. Observability Implementation

### Metrics Collection

The backend exposes Prometheus metrics at:

- `http://54.78.54.132:3000/metrics`

Core app SLI metrics used in dashboards and alerts:

- `http_requests_total`
- `http_errors_total`
- `http_request_duration_seconds` (histogram)

### Prometheus Scrape Targets

Prometheus scrapes:

- Backend app metrics (`172.31.3.138:3000`)
- App node exporter (`172.31.3.138:9100`)
- Observability node exporter (`localhost:9100`)
- Redis exporter (`172.31.3.138:9121`)
- Prometheus self-metrics (`localhost:9090`)

### Grafana Dashboards

The dashboards in use show:

- Requests per second (RPS)
- Error rate percentage
- p95 latency
- System utilization and host-level metrics

Current screenshots are stored in:

- `screenshots/backend-dashboard.png`
- `screenshots/redis-dashboard.png`
- `screenshots/system-dashboard.png`

## 3. Alerting Validation (High Error Rate > 5%)

### Alert Rules

Alert rules are defined in:

- `observability/prometheus/alert_rules.yml`

The critical rule:

- **Alert:** `HighErrorRate`
- **Expression:** `(sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m]))) * 100 > 5`
- **For:** `2m`

### Trigger Procedure Executed

1. Alert rules were copied to the live Prometheus host and loaded.
2. Error traffic was generated against:
   - `GET /api/fail`
3. Prometheus rule and alert APIs were polled until the state reached `firing`.

### Validation Results

Evidence file:

- `docs/evidence/prometheus-alerts-after-trigger.json`

Captured state confirms:

- `alertname=HighErrorRate`
- `state=firing`
- `severity=critical`
- Alert active time present in payload (`activeAt`)

Additional evidence:

- `docs/evidence/prometheus-high-error-rule-state.txt`
- `docs/evidence/error-traffic-run.txt` (40/40 HTTP 500 responses)

## 4. AWS Security and Logging Outcomes

### CloudWatch Logs

Container log groups and streams are present:

- `docs/evidence/cloudwatch-log-groups.json`
- `docs/evidence/cloudwatch-backend-streams.json`
- `docs/evidence/cloudwatch-frontend-streams.json`

Observed latest stream activity:

- Backend last event: `2026-02-22T11:15:49Z`
- Frontend last event: `2026-02-23T04:17:17Z`

This confirms Docker logging integration is active for backend/frontend deployments.

### CloudTrail and S3 Controls

CloudTrail and S3 policy/retention/encryption are validated from Terraform state snapshots:

- `docs/evidence/terraform-security-state-snippets.txt`

Key verified settings:

- CloudTrail enabled (`enable_logging=true`)
- Multi-region trail enabled (`is_multi_region_trail=true`)
- Trail writes to dedicated bucket `jenkins-cicd-observability-27035621`
- S3 server-side encryption set to `AES256`
- Lifecycle retention configured (`cloudtrail-retention`, 90-day expiry)

### GuardDuty

Terraform state confirms GuardDuty detector exists and is enabled:

- Detector resource `aws_guardduty_detector.main`
- `enable=true`

Evidence references:

- `docs/evidence/terraform-security-state-snippets.txt`
- `docs/evidence/guardduty-summary.txt` (runtime API visibility from EC2 role)

## 5. Constraints Observed During Validation

During evidence collection from the EC2 instance role:

- `cloudtrail:DescribeTrails` / `cloudtrail:GetTrailStatus` were denied
- `logs:GetLogEvents` was denied

These permission denials are expected under a restricted runtime role and indicate least-privilege boundaries are in effect. Resource creation and configuration are still verifiable through Terraform state and available read APIs.

## 6. Insights and Recommendations

### Reliability Insights

- Error-rate alerting is functional and sensitive enough to detect failure bursts quickly.
- Existing dashboards already provide the three required operational KPIs: RPS, latency p95, and error rate.
- Current architecture supports quick triage by correlating app metrics and host metrics.

### Security Insights

- CloudWatch log groups and streams are active for both app containers.
- CloudTrail is configured as a multi-region trail with encrypted S3 storage and lifecycle management.
- GuardDuty detector is enabled in-region.

### Recommended Next Steps

1. Add Alertmanager routing (email/Slack/PagerDuty) for actionable paging.
2. Add read-only IAM permissions for evidence collection roles (CloudTrail describe/status, CloudWatch get-log-events, GuardDuty list/get findings).
3. Add dashboard provisioning in userdata/automation so UIDs and screenshots are reproducible after rebuild.
4. Replace public Grafana exposure with VPN or private ALB + SSO.
5. Remove `/api/fail` or guard it behind non-production feature flags.

## 7. Cleanup Procedure

After demonstration and grading, clean up resources:

```bash
cd infra/terraform
terraform destroy
```

This removes EC2, CloudTrail, GuardDuty detector, S3 trail bucket, ECR repositories, and supporting IAM/security-group resources created by this stack.
