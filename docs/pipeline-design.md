# Pipeline Design and Good Practices

## Architecture Principles

- Keep pipeline stages focused and modular: quality, build, scan, push, deploy.
- Keep pipeline as code in `Jenkinsfile` under version control.
- Use one multibranch pipeline job so feature branches and `main` use the same logic.
- Deploy only from protected branches (`main` in this setup).

## Shift-Left Quality and Security

- Run lint and unit tests before Docker build.
- Run dependency vulnerability checks before image build.
- Optionally run SonarQube for static code analysis.
- Optionally run Trivy image scan before push/deploy.

## Credential and Secret Handling

- Use Jenkins Credentials for all secrets.
- Never hardcode credentials in `Jenkinsfile`.
- Avoid printing secrets in shell output.
- Prefer EC2 IAM role for runtime ECR pull on deploy host.

## ECR and Image Management

- Use immutable, traceable tags: `<branch>-<sha>-<build>`.
- Enable ECR scan-on-push.
- Use ECR lifecycle policies to remove stale images.
- Keep separate repositories for frontend and backend.

## Deployment Strategy

- SSH deploy script updates containers with minimal downtime.
- Keep backend and frontend in the same Docker network.
- Log containers to CloudWatch for centralized visibility.
- Run cleanup after deployment to avoid disk pressure.
