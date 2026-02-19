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
  description = "Subnet ID where EC2 instances will be launched"
  type        = string
}

variable "key_name" {
  description = "Existing AWS key pair name for SSH access"
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR allowed to access SSH/Jenkins/Grafana/Prometheus"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_instance_type" {
  description = "Instance type for Jenkins + app host"
  type        = string
  default     = "t3.micro"
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
  description = "Unique S3 bucket name for CloudTrail logs"
  type        = string
}

variable "cloudtrail_retention_days" {
  description = "Retention (days) for CloudTrail S3 objects"
  type        = number
  default     = 90
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}
