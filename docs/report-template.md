# Project 6 Report (Template)

## 1. Scope and Architecture
- Describe your two-instance architecture (`t3.micro` for Jenkins + app, `t3.medium` for observability).
- Include a diagram showing Jenkins, ECR, EC2 app host, Prometheus, Grafana, CloudWatch, CloudTrail, and GuardDuty.

## 2. CI/CD Implementation
- Summarize pipeline stages: checkout, lint/test/SAST, SonarQube, Docker build, scan, ECR push, deploy.
- Note branch behavior in multibranch pipeline (feature branches vs `main`).

## 3. Observability Outcomes
- Explain metrics collected (`http_requests_total`, `http_errors_total`, `http_request_duration_seconds`).
- Include dashboard screenshots for RPS, latency, error rates.
- Add evidence of alert trigger and resolution.

## 4. Security Outcomes
- CloudWatch logs evidence for backend/frontend containers.
- CloudTrail event samples (IAM/API activity).
- GuardDuty findings or confirmation of no critical findings during test period.

## 5. Insights and Improvements
- Key bottlenecks and reliability findings.
- Security posture strengths and gaps.
- Next actions (autoscaling, IaC state hardening, alert routing, secrets manager integration).
