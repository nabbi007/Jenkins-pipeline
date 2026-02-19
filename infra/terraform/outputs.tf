output "jenkins_public_ip" {
  description = "Public IP for Jenkins + app host"
  value       = aws_instance.jenkins_app.public_ip
}

output "jenkins_url" {
  description = "Jenkins UI URL"
  value       = "http://${aws_instance.jenkins_app.public_ip}:8080"
}

output "frontend_url" {
  description = "Frontend app URL"
  value       = "http://${aws_instance.jenkins_app.public_ip}"
}

output "backend_health_url" {
  description = "Backend health endpoint"
  value       = "http://${aws_instance.jenkins_app.public_ip}:3000/api/health"
}

output "backend_metrics_url" {
  description = "Backend Prometheus metrics endpoint"
  value       = "http://${aws_instance.jenkins_app.public_ip}:3000/metrics"
}

output "observability_public_ip" {
  description = "Public IP for Prometheus + Grafana host"
  value       = aws_instance.observability.public_ip
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_instance.observability.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.observability.public_ip}:9090"
}

output "backend_ecr_repository_url" {
  description = "Backend ECR repo URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repo URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "cloudtrail_bucket_name" {
  description = "CloudTrail log bucket"
  value       = aws_s3_bucket.cloudtrail.id
}
