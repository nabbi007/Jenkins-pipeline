# Project 6 - Full Observability and Security Solution

## Overview
This repository implements the Project 6 requirement to extend a containerized web application with full observability and AWS security controls.

The stack includes:
- Containerized voting app (frontend, backend, Redis)
- Prometheus for metrics collection
- Grafana for dashboards and alert visualization
- CloudWatch Logs for container log streaming
- CloudTrail for account activity auditing
- GuardDuty for threat detection

The backend exposes Prometheus metrics at `/metrics` and is deployed through Jenkins CI/CD.

## Project 6 Requirement Mapping
| Requirement | Implementation |
|---|---|
| App exposes metrics at `/metrics` | Backend endpoint: `http://<app-ip>:3000/metrics` |
| Prometheus deployment and scraping | `observability/prometheus/prometheus.yml` |
| Grafana dashboards (latency, RPS, error rate) | `observability/grafana/application-dashboard.json`, `observability/grafana/system-dashboard.json` |
| Alert for error rate > 5% | `observability/prometheus/alert_rules.yml` (`HighErrorRate`) |
| CloudWatch logging from containers | `scripts/deploy_backend.sh` and `scripts/deploy_frontend.sh` use `--log-driver=awslogs` |
| CloudTrail enabled with S3 storage/encryption/lifecycle | Terraform resources in `infra/terraform/main.tf` |
| GuardDuty enabled | `aws_guardduty_detector.main` in `infra/terraform/main.tf` |
| Verification evidence | `screenshots/`, `docs/evidence-checklist.md` |
| 2-page report | `docs/project6-report.md` |

## Repository Deliverables
| Submission item | Path in repo |
|---|---|
| Prometheus configuration | `observability/prometheus/prometheus.yml` |
| Alert rules | `observability/prometheus/alert_rules.yml` |
| Grafana dashboard JSON | `observability/grafana/application-dashboard.json`, `observability/grafana/system-dashboard.json` |
| Screenshots | `screenshots/` |
| 2-page report | `docs/project6-report.md` |
| Infra-as-code for AWS security services | `infra/terraform/` |

## Architecture Summary
Two-host AWS deployment:
- App/Jenkins EC2 host: Jenkins, frontend container, backend container, Redis, app metrics endpoint
- Observability EC2 host: Prometheus, Grafana, Node Exporter (plus optional Loki/Promtail scripts)

Security and logging resources:
- CloudWatch log groups for backend/frontend container logs
- CloudTrail trail with S3 bucket storage
- S3 controls: server-side encryption, versioning, lifecycle retention
- GuardDuty detector enabled

## Prerequisites
- AWS account with permissions for EC2, IAM, ECR, S3, CloudTrail, GuardDuty, CloudWatch
- Terraform >= 1.5
- AWS CLI configured locally
- Jenkins LTS and Docker on app host
- GitHub repository webhook to Jenkins (for automatic pipeline triggers)

## Deployment Steps
### 1. Provision infrastructure
```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# set subnet_id and secure values (or export TF_VAR_* env vars)
terraform init
terraform apply
```

Get output URLs:
```bash
terraform output
```

Key outputs:
- `frontend_url`
- `backend_health_url`
- `backend_metrics_url`
- `grafana_url`
- `prometheus_url`
- `cloudtrail_bucket_name`

### 2. Deploy the app through Jenkins
1. Create/scan a Jenkins multibranch pipeline for this repo.
2. Ensure Jenkins has credential `ec2_ssh`.
3. Push to `main` and run pipeline from `Jenkinsfile`.
4. Confirm stages complete through `Deploy To EC2`.

### 3. Verify metrics endpoint
```bash
curl -s http://<app_public_ip>:3000/metrics | head
```

### 4. Verify Prometheus scraping
Open:
- `http://<observability_public_ip>:9090/targets`

Expected:
- `backend` target `UP`
- `node_exporter` targets `UP`

### 5. Verify Grafana dashboards
Open:
- `http://<observability_public_ip>:3000`

Import dashboards from:
- `observability/grafana/application-dashboard.json`
- `observability/grafana/system-dashboard.json`

Required dashboard evidence:
- Requests per second
- Error rate
- Latency (p95)

### 6. Trigger and verify alerts
Generate failures to exceed 5% error rate:
```bash
./scripts/generate_error_traffic.sh http://<app_public_ip> 200
```

Validate in Prometheus:
- Alert rule file: `observability/prometheus/alert_rules.yml`
- Alert name: `HighErrorRate`
- Threshold: `> 5%` for 2 minutes

### 7. Verify AWS security telemetry
CloudWatch:
- Check log groups `/project/backend` and `/project/frontend`
- Confirm recent container log streams/events

CloudTrail:
- Confirm trail is enabled
- Confirm logs are delivered to S3 bucket from Terraform output
- Verify S3 encryption and lifecycle policy in Terraform resources

GuardDuty:
- Confirm detector is enabled in the AWS console
- Capture findings page (or no findings state)

## Local Validation (Optional)
```bash
docker compose -f docker-compose.app.yml up -d --build
curl http://localhost:3000/api/health
curl http://localhost:3000/metrics
docker compose -f docker-compose.app.yml down -v
```

## Evidence and Screenshots
Add these files under `screenshots/` for submission:
- `01-prometheus-targets-up.png`
- `02-grafana-rps-latency-error.png`
- `03-high-error-rate-alert-firing.png`
- `04-cloudwatch-log-groups-streams.png`
- `05-cloudtrail-trail-and-s3-logs.png`
- `06-guardduty-detector-findings.png`
- `07-app-metrics-endpoint.png`

Currently available:
- `screenshots/backend-dashboard.png`
- `screenshots/redis-dashboard.png`
- `screenshots/system-dashboard.png`

## Report
Project report is available at:
- `docs/project6-report.md`

Template:
- `docs/report-template.md`

## Cleanup
After demonstration:
```bash
cd infra/terraform
terraform destroy
```

This removes observability/security resources created for the project, including EC2 instances, CloudTrail trail/bucket policy dependencies, GuardDuty detector, and related infrastructure.
