# Terraform Infrastructure

This Terraform stack provisions:

- `t3.micro` EC2 for Jenkins + app deployment host
- `t3.medium` EC2 for Prometheus + Grafana
- ECR repositories (backend/frontend)
- CloudWatch log groups for container logs
- CloudTrail with encrypted S3 storage and lifecycle retention
- GuardDuty detector
- IAM instance profile for ECR, CloudWatch, and SSM

## Usage

```bash
cd infra/terraform
terraform init
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform plan -out tfplan
terraform apply tfplan
```

## Security Notes

- Restrict `allowed_cidr` to your public IP `/32`.
- Use strong `grafana_admin_password`.
- Store Terraform state in a secured remote backend for team usage.
- Prefer IAM roles for EC2 over static AWS credentials.
