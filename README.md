# Full CI/CD + Observability + Security Project

This repository delivers both assignments as one integrated system:

- Project CI/CD: Jenkins multibranch pipeline that builds, tests, scans, containerizes, pushes to ECR, and deploys to EC2.
- Project Observability/Security: Prometheus + Grafana + CloudWatch + CloudTrail + GuardDuty.

## Stack

- Backend: Node.js + Express + Prometheus metrics
- Frontend: Static web UI served by Nginx
- CI/CD: Jenkins LTS multibranch pipeline
- Registry: AWS ECR
- Infra as Code: Terraform
- Monitoring: Prometheus + Grafana + Node Exporter
- AWS Security: CloudWatch Logs, CloudTrail, GuardDuty

## Repository Layout

- `backend/` backend service, tests, Dockerfile
- `frontend/` frontend app, tests, Dockerfile
- `Jenkinsfile` multibranch pipeline definition
- `scripts/` deploy and utility scripts
- `infra/terraform/` Terraform infrastructure for AWS
- `observability/` Prometheus and Grafana configs
- `docs/` runbook, report template, evidence checklist

## Quick Start (Order)

1. Provision AWS infrastructure with Terraform from `infra/terraform/`.
2. Access Jenkins on the `t3.micro` instance at port `8080`.
3. Install plugins listed in `jenkins/plugins.txt`.
4. Configure Jenkins multibranch pipeline pointing to this repo.
5. Add Jenkins credentials:
- `registry_creds` (AWS access key/secret for ECR push)
- `ec2_ssh` (SSH private key for deploy host)
- `sonarqube_token` (optional, if SonarQube enabled)
6. Run pipeline on a feature branch and `main` branch.
7. Verify application and monitoring endpoints.

Detailed execution instructions are in `docs/runbook.md`.

## Helpful Commands

```bash
make backend-install backend-lint backend-test
make frontend-install frontend-lint frontend-test frontend-build
make compose-up
make compose-down
make terraform-fmt
```
