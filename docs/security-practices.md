# Security Best Practices

## Jenkins

- Run Jenkins with least-privilege IAM access.
- Restrict Jenkins UI exposure by IP using security groups.
- Keep plugins updated and limited to required set.
- Use matrix authorization and disable anonymous read.

## Pipeline

- Block deployment from non-protected branches.
- Fail pipeline on test/lint/security gate failures.
- Use signed commits and branch protection rules.
- Enforce code reviews before merge to `main`.

## Docker

- Use minimal base images and non-root users.
- Keep image layers small and deterministic.
- Avoid embedding secrets in image or build args.
- Scan images and dependencies continuously.

## Prometheus and Grafana

- Keep Grafana/Prometheus ports restricted to admin CIDR.
- Rotate Grafana admin credentials.
- Use alert routing to email/Slack/PagerDuty.
- Version dashboards and alert rules in Git.

## AWS

- Enable CloudTrail in all regions.
- Encrypt CloudTrail logs at rest in S3.
- Add S3 lifecycle retention to control cost.
- Keep GuardDuty enabled and review findings regularly.
