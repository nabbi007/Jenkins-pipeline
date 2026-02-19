# Architecture and Delivery Plan

## Target Topology

- `EC2 t3.micro`: Jenkins LTS + Docker + deployed frontend/backend containers.
- `EC2 t3.medium`: Prometheus + Grafana + Node Exporter.
- `AWS ECR`: backend/frontend image repositories.
- `CloudWatch Logs`: Docker container logs (`/project/backend`, `/project/frontend`).
- `CloudTrail + S3`: account/API audit logs with encryption and lifecycle.
- `GuardDuty`: threat detection.

## Delivery Sequence

1. Provision infrastructure with Terraform (`infra/terraform`).
2. Push repository to GitHub.
3. Configure Jenkins multibranch pipeline on the `t3.micro` host.
4. Add credentials (`registry_creds`, `ec2_ssh`, optional `sonarqube_token`).
5. Build and test on all branches.
6. Push images to ECR after quality/security gates pass.
7. Deploy only from `main` to EC2 via SSH scripts.
8. Validate app endpoint, metrics, dashboards, and alerts.
9. Collect screenshots/log evidence.
10. Cleanup resources.

## Jenkins Best Practices Used

- Pipeline as code (`Jenkinsfile`) under Git.
- Multibranch pipeline for branch isolation and PR checks.
- Shift-left stages before image build.
- Optional SonarQube and Trivy stages.
- Credentials stored in Jenkins Credentials store.
- Cleanup stage to control Docker disk usage.

## Docker Best Practices Used

- Non-root backend container.
- Minimal base images (`node:20-alpine`, `nginx:alpine`).
- Healthchecks for both services.
- Separate frontend/backend images and tags.
- Prune old images post-deploy.

## Prometheus/Grafana Best Practices Used

- App metrics exposed at `/metrics`.
- Node Exporter host metrics.
- Alert rules for error rate and latency.
- Dashboard versioned in Git (`backend-dashboard.json`).
- Security groups restrict dashboard/monitoring ports.
