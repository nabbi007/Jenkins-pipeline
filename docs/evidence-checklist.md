# Evidence Checklist

- Jenkins multibranch pipeline job overview.
- Successful pipeline run showing stages from build to deploy.
- ECR repositories with pushed image tags.
- EC2 app accessible via public IP/DNS.
- Voting app UI reachable and interactive on EC2.
- `/api/health`, `/api/poll`, `/api/results`, and `/metrics` reachable.
- Prometheus targets page showing `UP` status.
- Grafana dashboard screenshots (RPS, error %, p95 latency).
- Alert screenshot for >5% error rate.
- CloudWatch log group entries for backend/frontend containers.
- CloudTrail events in S3 and console.
- GuardDuty detector/findings view.
