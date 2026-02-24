# Jenkins CI/CD Pipeline with Full Observability

A CI/CD and observability platform built on AWS. It delivers a Node.js voting application through an automated Jenkins pipeline and monitors the entire stack with Prometheus, Grafana.

---

## What the Application Does

The app is a **real-time team voting poll**. Users pick which team should host the next company townhall from three choices: Engineering, Product, or Design. Each vote is stored in Redis and exposed via a REST API. The frontend is a single-page HTML app served by Nginx that calls the backend.

---

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │         Developer / GitHub          │
                    │    git push → webhook trigger       │
                    └──────────────────┬──────────────────┘
                                       │
                    ┌──────────────────▼──────────────────┐
                    │        APP EC2 (54.78.54.132)       │
                    │  ┌─────────────────────────────┐    │
                    │  │  Jenkins (port 8080)         │    │
                    │  │  - Lint → Test → Scan        │    │
                    │  │  - Docker Build              │    │
                    │  │  - Push to AWS ECR           │    │
                    │  │  - Deploy via SSH            │    │
                    │  └─────────────────────────────┘    │
                    │                                     │
                    │  ┌──────────┐  ┌────────────────┐   │
                    │  │ Nginx    │  │ Node.js Backend│   │
                    │  │ port 80  │  │ port 3000      │   │
                    │  └──────────┘  └────────────────┘   │
                    │         ┌──────────────┐            │
                    │         │  Redis       │            │
                    │         │  port 6379   │            │
                    │         └──────────────┘            │
                    │         ┌──────────────┐            │
                    │         │ Node Exporter│            │
                    │         │ port 9100    │            │
                    │         └──────────────┘            │
                    │         ┌──────────────┐            │
                    │         │Redis Exporter│            │
                    │         │ port 9121    │            │
                    │         └──────────────┘            │
                    └─────────────────────────────────────┘
                                       │  scrape metrics
                    ┌──────────────────▼──────────────────┐
                    │    OBSERVABILITY EC2 (108.130.163.21)│
                    │  ┌────────────┐  ┌───────────────┐  │
                    │  │ Prometheus │  │    Grafana    │  │
                    │  │ port 9090  │  │   port 3000   │  │
                    │  └────────────┘  └───────────────┘  │
                    │  ┌────────────┐  ┌───────────────┐  │
                    │  │    Loki    │  │   Promtail    │  │
                    │  │ port 3100  │  │   port 9080   │  │
                    │  └────────────┘  └───────────────┘  │
                    └─────────────────────────────────────┘
```

### Infrastructure

| Component | Host | Notes |
|-----------|------|-------|
| Jenkins | App EC2 | Runs builds and deploys |
| Backend API | App EC2 | Node.js/Express, port 3000 |
| Frontend | App EC2 | Nginx serving static files, port 80 |
| Redis | App EC2 | Docker container, vote store |
| Node Exporter | App EC2 | Systemd service, system metrics |
| Redis Exporter | App EC2 | Docker container, Redis metrics |
| Prometheus | Obs EC2 | Systemd service, scrapes all targets |
| Grafana | Obs EC2 | Systemd service, dashboards |
| Loki | Obs EC2 | Docker container, log store |
| Promtail | Obs EC2 | Docker container, ships logs |

---

## CI/CD Pipeline

The Jenkins pipeline runs automatically when you push to `main`. It has 9 stages:

```
Checkout → Prepare Metadata → Backend Lint/Test/Audit → Frontend Lint/Test/Build
         → SonarQube Scan → Docker Build → Trivy Security Scan
         → Push to ECR → Deploy to EC2 → Cleanup
```

**Key behaviours:**
- Docker images are tagged as `<branch>-<git-sha>-<build-number>` (e.g. `main-a1b2c3d4-42`)
- The AWS account ID is auto-detected from the EC2 IAM role — no secrets stored in Jenkins for AWS
- SonarQube and Trivy scans are skipped gracefully if not installed
- Deployment only happens on the `main` branch when `DEPLOY_HOST` is set
- Old images are pruned automatically at the end of every build

### Pipeline Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `AWS_REGION` | `eu-west-1` | AWS region for ECR and EC2 |
| `ECR_ACCOUNT_ID` | auto | AWS account ID (auto-detected from IAM role) |
| `BACKEND_ECR_REPO` | `backend-service` | ECR repository name |
| `FRONTEND_ECR_REPO` | `frontend-web` | ECR repository name |
| `DEPLOY_HOST` | _blank_ | EC2 public IP to deploy to |
| `ENABLE_SONARQUBE` | `true` | Run SonarQube static analysis |
| `ENABLE_TRIVY` | `true` | Run Trivy container scanning |

---

## Observability

### Prometheus Targets

Prometheus scrapes these targets every 15 seconds:

| Job | Target | What it monitors |
|-----|--------|-----------------|
| `backend` | `172.31.3.138:3000` | App request rates, errors, latency, vote counts |
| `node_exporter` | `172.31.3.138:9100` | CPU, memory, disk, network on app EC2 |
| `node_exporter` | `localhost:9100` | Same metrics on obs EC2 |
| `redis` | `172.31.3.138:9121` | Redis connections, memory, ops/sec |
| `prometheus` | `localhost:9090` | Prometheus self-metrics |

### Grafana Dashboards

| Dashboard | Purpose |
|-----------|---------|
| **Application Dashboard** | Request rate, error rate, latency percentiles, Redis health, vote counts |
| **System Dashboard** | CPU, memory, disk I/O, network, filesystem usage, load average |

Access: **http://108.130.163.21:3000** — login `admin` / `admin`

### Application Metrics (Custom)

The backend exposes these custom metrics at `/metrics`:

| Metric | Type | Description |
|--------|------|-------------|
| `http_requests_total` | Counter | Total requests by method, route, status |
| `http_request_duration_seconds` | Histogram | Latency percentiles |
| `http_errors_total` | Counter | 4xx/5xx errors |
| `votes_total` | Counter | Votes cast per option |
| `votes_current` | Gauge | Current vote tally per option |
| `redis_connection_status` | Gauge | 1 = connected, 0 = disconnected |
| `poll_views_total` | Counter | How many times the poll was viewed |
| `results_views_total` | Counter | How many times results were viewed |

### Project 6 Deliverables (Report + Evidence)

- **2-page report:** `docs/project6-report.md`
- **Evidence index:** `docs/evidence/README.md`

#### Dashboard Screenshots

Backend service dashboard:

![Backend Dashboard](screenshots/backend-dashboard.png)

Application and Redis dashboard:

![Redis Dashboard](screenshots/redis-dashboard.png)

System metrics dashboard:

![System Dashboard](screenshots/system-dashboard.png)

#### Alert Trigger Validation (`HighErrorRate > 5%`)

Trigger command used:

```bash
./scripts/generate_error_traffic.sh http://54.78.54.132 900
```

Prometheus alert state after trigger:

```json
{"labels":{"alertname":"HighErrorRate","severity":"critical"},"state":"firing","activeAt":"2026-02-23T04:18:35.19523625Z"}
```

Full evidence files:

- `docs/evidence/prometheus-alerts-after-trigger.json`
- `docs/evidence/prometheus-high-error-rule-state.txt`
- `docs/evidence/error-traffic-run.txt`

#### CloudWatch, CloudTrail, and GuardDuty Evidence

- CloudWatch log groups and streams:
  - `docs/evidence/cloudwatch-log-groups.json`
  - `docs/evidence/cloudwatch-backend-streams.json`
  - `docs/evidence/cloudwatch-frontend-streams.json`
- CloudTrail and GuardDuty provisioning/state evidence:
  - `docs/evidence/terraform-security-state-snippets.txt`
- Runtime AWS API permission outputs from EC2 role context:
  - `docs/evidence/cloudtrail-trails.json`
  - `docs/evidence/cloudtrail-trail-status.json`
  - `docs/evidence/guardduty-summary.txt`

---

## Repository Layout

```
.
├── backend/                  Node.js/Express API
│   ├── src/
│   │   ├── app.js           Main app with all routes and metrics
│   │   ├── server.js        HTTP server entry point
│   │   └── redis.js         Redis client with graceful fallback
│   ├── tests/app.test.js    Jest test suite (8 tests)
│   └── Dockerfile
├── frontend/                 Static HTML/CSS/JS
│   ├── src/                 Source files
│   ├── nginx.conf           Nginx config (reverse proxy to backend)
│   └── Dockerfile
├── infra/terraform/          AWS infrastructure as code
│   ├── main.tf              EC2 instances, security groups
│   ├── variables.tf         Input variables
│   ├── outputs.tf           Public IPs and URLs
│   └── templates/           EC2 userdata scripts
├── observability/
│   ├── grafana/             Dashboard JSON files (2 dashboards)
│   └── prometheus/          Alert rules, local dev config
├── scripts/                  Operational scripts
│   ├── deploy_backend.sh    Used by pipeline to pull + run backend
│   ├── deploy_frontend.sh   Used by pipeline to pull + run frontend
│   ├── deploy_observability.sh  Set up obs stack on obs EC2
│   ├── redeploy_backend.sh  Manual force-redeploy of backend
│   ├── generate_traffic.sh  Send test traffic to the app
│   ├── generate_error_traffic.sh  Trigger errors for testing alerts
│   ├── import_dashboards.sh Restore Grafana dashboards via API
│   ├── verify_observability.sh  Health check all obs components
│   ├── cleanup_docker.sh    Remove unused Docker images/containers
│   └── install_jenkins_plugins.sh  Bootstrap Jenkins plugins
├── jenkins/plugins.txt       Jenkins plugin list
├── docs/                     Architecture, runbooks, report, and evidence
│   ├── project6-report.md   2-page Project 6 summary report
│   └── evidence/            Alert and AWS validation artifacts
├── docker-compose.app.yml    Local development stack
├── Jenkinsfile               Pipeline definition
└── sonar-project.properties  SonarQube config
```

---

## How to Run

### Prerequisites

- AWS account with permissions to create EC2, ECR, S3, IAM roles
- Terraform >= 1.5 installed locally
- AWS CLI configured (for initial Terraform apply)
- Git

### Step 1 — Provision Infrastructure

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set your region, allowed_cidr (your IP), key_name
terraform init
terraform apply
# Note the output IPs: jenkins_app_public_ip and observability_public_ip
```

Terraform creates:
- 2 EC2 instances with IAM roles
- Security groups with least-privilege rules
- ECR repositories for backend and frontend
- CloudTrail, S3 log bucket

### Step 2 — Configure Jenkins

1. Navigate to `http://<jenkins_app_public_ip>:8080`
2. Get initial password: `ssh ec2-user@<ip> "cat /var/lib/jenkins/secrets/initialAdminPassword"`
3. Install suggested plugins + add from `jenkins/plugins.txt`
4. Add these credentials in Jenkins → Manage Credentials:
   - `ec2_ssh` — SSH private key (the `.pem` from Terraform output)
   - `sonarqube_token` — SonarQube token (optional)
5. Create a **Multibranch Pipeline** pointing to this GitHub repo
6. Add a webhook in GitHub: `http://<jenkins-ip>:8080/github-webhook/`

### Step 3 — First Build

In Jenkins, open the `main` branch pipeline and click **Build with Parameters**:
- Set `DEPLOY_HOST` to your app EC2 public IP
- Click Save to persist this setting

Push a commit to `main` or click **Build Now**.

### Step 4 — Deploy Observability

After the first build succeeds:

```bash
export SSH_KEY="infra/terraform/<your-key>.pem"
export OBS_IP="<observability_public_ip>"
scp -i "$SSH_KEY" scripts/deploy_observability.sh ec2-user@$OBS_IP:/tmp/
ssh -i "$SSH_KEY" ec2-user@$OBS_IP "bash /tmp/deploy_observability.sh"
```

### Step 5 — Access Everything

| Service | URL | Credentials |
|---------|-----|-------------|
| Voting App | `http://<app-ip>` | — |
| Backend API | `http://<app-ip>:3000/api/health` | — |
| Prometheus metrics | `http://<app-ip>:3000/metrics` | — |
| Jenkins | `http://<app-ip>:8080` | admin / set on first login |
| Grafana | `http://<obs-ip>:3000` | admin / admin |
| Prometheus UI | `http://<obs-ip>:9090` | — |

---

## Local Development

Run the full stack locally (no AWS needed):

```bash
# Start Redis + Backend + Frontend
docker compose -f docker-compose.app.yml up

# App available at http://localhost:80
# Backend API at http://localhost:3000
# Metrics at http://localhost:3000/metrics
```

Run tests:

```bash
cd backend
npm install
npm test               # watch mode
npm run test:ci        # single run with coverage (used by pipeline)
```

Run linting:

```bash
cd backend && npm run lint
cd frontend && npm run lint
```

---

## Backend API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check — returns `{ status: "ok" }` |
| GET | `/api/poll` | Returns poll question and options |
| POST | `/api/vote` | Cast a vote — body: `{ "option": "Engineering" }` |
| GET | `/api/results` | Returns current vote totals |
| GET | `/metrics` | Prometheus metrics endpoint |
| GET | `/api/fail` | Always returns 500 (for testing alerts) |

---

## Useful Scripts

```bash
# Generate 30 requests for testing dashboards
./scripts/generate_traffic.sh http://<app-ip> 30

# Generate error traffic to test alert rules
./scripts/generate_error_traffic.sh http://<app-ip>

# Force redeploy backend from latest ECR image
./scripts/redeploy_backend.sh

# Check all observability components are healthy
./scripts/verify_observability.sh

# Restore Grafana dashboards after a wipe
./scripts/import_dashboards.sh http://<obs-ip>:3000 admin admin
```

---

## Security Notes

> These are known limitations of this project as a learning/demo environment. They should be addressed before any production use.

| # | Issue | Risk | Fix |
|---|-------|------|-----|
| 1 | **Default Grafana password** `admin/admin` | Anyone with network access can view all metrics and modify dashboards | Change via Grafana UI → Profile or set `GF_SECURITY_ADMIN_PASSWORD` env var |
| 2 | **No HTTPS anywhere** | All traffic (Jenkins, Grafana, backend API, app) is plain HTTP | Add TLS via ALB with ACM certificate or reverse proxy with Let's Encrypt |
| 3 | **Redis has no password** | Any process that can reach port 6379 can read or overwrite all votes | Add `requirepass` in Redis config and update `REDIS_URL` |
| 4 | **Prometheus and Grafana have public IPs** | Security groups currently restrict by source IP, but the observability stack has no application-level auth | Place behind VPN or bastion; enable Grafana auth properly |
| 5 | **No API authentication** | The backend voting API has no auth — anyone can cast votes programmatically | Add API key middleware or rate limiting |
| 6 | **`/api/fail` endpoint in production** | Intentional 500 endpoint was added for alert testing — should not be accessible in production | Guard with `if (process.env.NODE_ENV !== 'production')` check |
| 7 | **Jenkins runs over HTTP** | Login credentials and build logs sent unencrypted | Put Jenkins behind an HTTPS reverse proxy (Nginx + Let's Encrypt) |
| 8 | **No rate limiting on API** | The vote endpoint can be flooded, inflating counts or causing DoS | Add `express-rate-limit` middleware |
| 9 | **AWS session credentials in shell history** | Temporary credentials shared in this session are visible in terminal history | Always use IAM roles on EC2 instead of static/temporary credentials |
| 10 | **Broad EC2 IAM role** | The `jenkins-cicd-observability-ec2-role` has ECR, ECS and other permissions | Apply least-privilege — scope to only what Jenkins needs (ECR push, STS) |
