# Complete CI/CD Pipeline with Jenkins

## Project Summary
This project implements an end-to-end CI/CD pipeline in Jenkins for a web voting service. The pipeline checks out code, runs quality gates, builds Docker images, pushes images to a registry (AWS ECR), deploys to an EC2 host over SSH, and performs cleanup.

The implementation in this repository uses:
- Backend: Node.js + Express
- Frontend: Static web app served by Nginx
- Data store: Redis
- CI/CD: Jenkins Pipeline (`Jenkinsfile`)
- Registry: AWS ECR
- Deployment target: Amazon EC2 (Amazon Linux 2)

## Deliverables Coverage
| Requirement | Implementation in this repo |
|---|---|
| Simple app with tests | `backend/` and `frontend/` with unit tests |
| Dockerfile(s) | `backend/Dockerfile`, `frontend/Dockerfile` |
| Jenkins pipeline | Root `Jenkinsfile` |
| Pipeline stages | Checkout, build/test, Docker build, push, deploy, cleanup |
| Push image to registry | `Push Image To ECR` stage |
| Deploy to EC2 via SSH | `Deploy To EC2` stage using `ec2_ssh` credential |
| Evidence and runbook | `docs/runbook.md`, `docs/evidence-checklist.md`, `screenshots/` |

## Repository Structure
| Path | Purpose |
|---|---|
| `Jenkinsfile` | Full CI/CD pipeline definition |
| `backend/` | Express API and tests |
| `frontend/` | Frontend app and tests |
| `scripts/deploy_backend.sh` | Pull and run backend image on EC2 |
| `scripts/deploy_frontend.sh` | Pull and run frontend image on EC2 |
| `scripts/install_jenkins_plugins.sh` | Jenkins plugin installation helper |
| `jenkins/plugins.txt` | Required Jenkins plugins list |
| `docs/runbook.md` | Operational runbook |
| `screenshots/` | Pipeline and deployment evidence images |

## Jenkins Prerequisites
Install these on your Jenkins host (Amazon Linux 2):
- Jenkins LTS
- Docker Engine
- AWS CLI
- Git
- Node.js/npm (required for lint/test/build stages)

Ensure the `jenkins` user can run Docker:
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

## Required Jenkins Plugins
Install the required plugins:
- Pipeline (`workflow-aggregator`)
- Git
- Credentials Binding
- Docker Pipeline (`docker-workflow`)
- SSH Agent

This repo already provides:
- Plugin list: `jenkins/plugins.txt`
- Installer script: `scripts/install_jenkins_plugins.sh`

Example:
```bash
./scripts/install_jenkins_plugins.sh jenkins/plugins.txt
```

## Jenkins Credentials
Create the following credentials in Jenkins:

| Credential ID | Type | Required | Usage |
|---|---|---|---|
| `git_credentials` | Username/Password or PAT | Optional | Private GitHub checkout |
| `registry_creds` | Username/Password | Optional in this implementation | Use if you switch to Docker Hub/GHCR |
| `ec2_ssh` | SSH private key | Yes | SSH/SCP deployment to EC2 |
| `sonarqube_token` | Secret text | Optional | SonarQube stage (if enabled) |

Note: Current pipeline pushes to AWS ECR using AWS CLI/IAM on the Jenkins host, so `registry_creds` is not required unless you change registries.

## Pipeline Stages
The implemented pipeline stages are:
1. `Checkout`
2. `Prepare Metadata`
3. `Shift Left - Backend Lint/Test/SAST`
4. `Shift Left - Frontend Lint/Test/Build`
5. `SonarQube Scan` (optional)
6. `Docker Build`
7. `Container Security Scan` (optional)
8. `Push Image To ECR`
9. `Deploy To EC2` (main branch)
10. `Cleanup`

Assignment stage mapping:
- Checkout -> `Checkout`
- Install/Build -> backend/frontend install and frontend build stages
- Test -> backend/frontend `test:ci`
- Docker Build -> `Docker Build`
- Push Image -> `Push Image To ECR`
- Deploy (SSH) -> `Deploy To EC2`

## How to Run
### 1. Clone the repository
```bash
git clone https://github.com/nabbi007/Jenkins-pipeline.git
cd Jenkins-pipeline
```

### 2. Create Jenkins pipeline job
Recommended: Multibranch Pipeline
1. Jenkins -> New Item -> Multibranch Pipeline
2. Add GitHub repository source
3. Set script path to `Jenkinsfile`
4. Configure webhook trigger (or poll)

### 3. Configure pipeline parameters
Common parameters in `Jenkinsfile`:
- `AWS_REGION` (default `eu-west-1`)
- `ECR_ACCOUNT_ID` (optional; auto-detected if blank)
- `BACKEND_ECR_REPO` (default `backend-service`)
- `FRONTEND_ECR_REPO` (default `frontend-web`)
- `DEPLOY_HOST` (optional; auto-detected if blank on EC2)
- `ENABLE_SONARQUBE` / `ENABLE_TRIVY`

### 4. Run pipeline
- Commit and push to branch
- Jenkins runs stages automatically
- Deploy executes on `main` when deploy host is resolved

### 5. Verify deployment
Replace `<EC2_PUBLIC_IP>`:
```bash
curl http://<EC2_PUBLIC_IP>/
curl http://<EC2_PUBLIC_IP>:3000/api/health
curl http://<EC2_PUBLIC_IP>:3000/api/poll
curl http://<EC2_PUBLIC_IP>:3000/api/results
curl http://<EC2_PUBLIC_IP>:3000/metrics
```

Expected:
- Frontend reachable on port `80`
- Backend health endpoint returns `status: ok`
- Poll/results endpoints return JSON
- Metrics endpoint responds

## Local Run (Optional)
Use Docker Compose for local validation:
```bash
docker compose -f docker-compose.app.yml up -d --build
curl http://localhost:8081
curl http://localhost:3000/api/health
```

Stop local stack:
```bash
docker compose -f docker-compose.app.yml down -v
```

## Cleanup After Deployment
Pipeline cleanup runs `docker image prune -f`.

Manual cleanup on EC2 (if needed):
```bash
docker rm -f frontend backend redis || true
docker image prune -af || true
```

## Evidence and Screenshots
Add your screenshots to `screenshots/` and keep the naming below (or rename links accordingly).

### 1. Jenkins pipeline successful run
![Jenkins pipeline success](screenshots/jenkins-success.png)

### 2. Jenkins stage view (build -> test -> push -> deploy)
![Jenkins stage view](screenshots/stages.png)

### 3. ECR images pushed
![ECR images](screenshots/ecr.png)

### 6. Jenkins console output for deploy stage
![Deploy logs](screenshots/deploy-logs.png)


## Runbook and Supporting Docs
- `docs/runbook.md`
- `docs/evidence-checklist.md`
- `docs/pipeline-design.md`

These files contain detailed operational and verification steps for demonstration/submission.
