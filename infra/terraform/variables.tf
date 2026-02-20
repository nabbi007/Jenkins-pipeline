variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project tag and resource prefix"
  type        = string
  default     = "jenkins-cicd-observability"
}

variable "subnet_id" {
  description = "Subnet ID where EC2 instances will be launched. Set via TF_VAR_subnet_id env var."
  type        = string
  default     = null
}

variable "key_name" {
  description = "Existing AWS key pair name for SSH access. Used only when use_existing_key=true."
  type        = string
  default     = null
}

variable "use_existing_key" {
  description = "If true, use key_name as an existing EC2 key pair. If false, Terraform generates a new key pair and local PEM."
  type        = bool
  default     = false
}

variable "allowed_cidr" {
  description = "CIDR allowed to access SSH/Jenkins/Grafana/Prometheus. Set via TF_VAR_allowed_cidr env var."
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_instance_type" {
  description = "Instance type for Jenkins + app host"
  type        = string
  default     = "t3.medium"
}

variable "observability_instance_type" {
  description = "Instance type for Prometheus + Grafana host"
  type        = string
  default     = "t3.medium"
}

variable "backend_ecr_repo_name" {
  description = "ECR repository name for backend"
  type        = string
  default     = "backend-service"
}

variable "frontend_ecr_repo_name" {
  description = "ECR repository name for frontend"
  type        = string
  default     = "frontend-web"
}

variable "cloudtrail_s3_bucket_name" {
  description = "Unique S3 bucket name for CloudTrail logs. Auto-generated if not provided."
  type        = string
  default     = null
}

variable "cloudtrail_retention_days" {
  description = "Retention (days) for CloudTrail S3 objects"
  type        = number
  default     = 90
}

variable "grafana_admin_password" {
  description = "Initial admin password for Grafana. Change it in the Grafana UI after first login."
  type        = string
  sensitive   = true
  default     = "admin"
}
