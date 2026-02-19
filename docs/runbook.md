# Runbook: End-to-End Delivery

## 1. Provision Infrastructure (Terraform)

Run from `infra/terraform`:

```bash
terraform init
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your subnet/key/bucket/password values
terraform plan -out tfplan
terraform apply tfplan
```

Collect outputs:

- `jenkins_url`
- `frontend_url`
- `backend_health_url`
- `backend_metrics_url`
- `grafana_url`
- `prometheus_url`

## 2. Jenkins Host Setup Validation

SSH into Jenkins/app host (`t3.micro`):

```bash
ssh -i <key.pem> ec2-user@<jenkins_public_ip>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

Install required plugins from `jenkins/plugins.txt`.

## 3. Configure Jenkins Credentials

Create these credentials in Jenkins:

- `registry_creds` as Username/Password
  - username: AWS Access Key ID
  - password: AWS Secret Access Key
- `ec2_ssh` as SSH private key for EC2 deploy user
- `sonarqube_token` as Secret Text (optional)

If SonarQube is used, define `SONAR_HOST_URL` in Jenkins global env.

## 4. Configure Multibranch Pipeline

1. New Item -> Multibranch Pipeline.
2. Add GitHub source to this repo.
3. Set `Jenkinsfile` path to root `Jenkinsfile`.
4. Enable webhook trigger from GitHub.
5. Scan repository now.

## 5. Pipeline Stage Behavior

Pipeline stages:

1. `Checkout`
2. `Prepare Metadata`
3. `Shift Left - Backend Lint/Test/SAST`
4. `Shift Left - Frontend Lint/Test/Build`
5. `SonarQube Scan (Optional)`
6. `Docker Build`
7. `Container Security Scan (Optional)`
8. `Push Image To ECR`
9. `Deploy To EC2` (`main` branch only)
10. `Cleanup`

## 6. Verify Deployment

```bash
curl http://<app_public_ip>/
curl http://<app_public_ip>:3000/api/health
curl http://<app_public_ip>:3000/api/poll
curl http://<app_public_ip>:3000/api/results
curl http://<app_public_ip>:3000/metrics
```

Expected:

- Frontend responds on port `80`
- Backend health returns `{"status":"ok",...}`
- Poll endpoint returns question + options
- Results endpoint returns current vote totals and storage mode (`redis` or fallback `memory`)
- Metrics include `http_requests_total`

## 7. Observability Validation

Prometheus:

- Open `http://<observability_ip>:9090/targets`
- Ensure `backend` and `node_exporter` are `UP`

Grafana:

- Open `http://<observability_ip>:3000`
- Login `admin` with `grafana_admin_password` from tfvars
- Import `observability/grafana/backend-dashboard.json`
- Confirm RPS, error rate, and p95 panels receive data

Trigger alert test:

```bash
./scripts/generate_error_traffic.sh http://<app_public_ip> 200
```

Confirm `HighErrorRate` fires in Prometheus/Grafana.

## 8. AWS Security Validation

CloudWatch:

- Log groups `/project/backend` and `/project/frontend` receive container logs.

CloudTrail:

- Trail is enabled and writing to configured S3 bucket.
- Verify API events in CloudTrail console.

GuardDuty:

- Detector enabled.
- Capture findings page screenshot (or no findings state).

## 9. Cleanup

To destroy infrastructure:

```bash
cd infra/terraform
terraform destroy
```

Also clean local Docker artifacts on hosts when needed:

```bash
./scripts/cleanup_docker.sh
```
