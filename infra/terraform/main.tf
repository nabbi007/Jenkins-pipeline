# Generate random suffix for globally unique S3 bucket name.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  common_tags = {
    Project = var.project_name
    Managed = "terraform"
  }
  # Use provided bucket name or auto-generate one.
  cloudtrail_bucket_name = coalesce(
    var.cloudtrail_s3_bucket_name,
    "${var.project_name}-${random_id.bucket_suffix.hex}"
  )
  # Default Grafana password if not provided via env var.
  grafana_password = coalesce(var.grafana_admin_password, "ChangeMe123!")
  # Generate EC2 key pair by default. Use existing key only when explicitly requested.
  requested_existing_key_name = trimspace(var.key_name == null ? "" : var.key_name)
  use_existing_key            = var.use_existing_key && local.requested_existing_key_name != ""
  generate_ssh_key            = !local.use_existing_key
  effective_key_name          = local.use_existing_key ? local.requested_existing_key_name : "${var.project_name}-ec2-${random_id.bucket_suffix.hex}"
  generated_private_key_path  = "${path.module}/${local.effective_key_name}.pem"
}

resource "tls_private_key" "ec2" {
  count = local.generate_ssh_key ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2" {
  count = local.generate_ssh_key ? 1 : 0

  key_name   = local.effective_key_name
  public_key = tls_private_key.ec2[0].public_key_openssh

  tags = merge(local.common_tags, {
    Name = local.effective_key_name
  })
}

resource "local_file" "ec2_private_key" {
  count = local.generate_ssh_key ? 1 : 0

  filename        = local.generated_private_key_path
  content         = tls_private_key.ec2[0].private_key_pem
  file_permission = "0400"
}

resource "aws_security_group" "jenkins_app" {
  name        = "${var.project_name}-jenkins-app-sg"
  description = "Jenkins + App security group"
  vpc_id      = data.aws_subnet.selected.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Frontend"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Backend API"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description     = "Backend metrics access from observability host"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.observability.id]
  }

  ingress {
    description     = "Node exporter from observability host"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.observability.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-jenkins-app-sg"
  })
}

resource "aws_security_group" "observability" {
  name        = "${var.project_name}-observability-sg"
  description = "Prometheus + Grafana security group"
  vpc_id      = data.aws_subnet.selected.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Node exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-observability-sg"
  })
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecr_power_user" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_ecr_repository" "backend" {
  name                 = var.backend_ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = var.backend_ecr_repo_name
  })
}

resource "aws_ecr_repository" "frontend" {
  name                 = var.frontend_ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = var.frontend_ecr_repo_name
  })
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/project/backend"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/project/frontend"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_instance" "jenkins_app" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.app_instance_type
  key_name                    = local.generate_ssh_key ? aws_key_pair.ec2[0].key_name : var.key_name
  subnet_id                   = local.effective_subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins_app.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/jenkins_app_userdata.sh.tftpl", {
    region = var.region
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-jenkins-app"
  })
}

resource "aws_instance" "observability" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.observability_instance_type
  key_name                    = local.generate_ssh_key ? aws_key_pair.ec2[0].key_name : var.key_name
  subnet_id                   = local.effective_subnet_id
  vpc_security_group_ids      = [aws_security_group.observability.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/observability_userdata.sh.tftpl", {
    app_private_ip         = aws_instance.jenkins_app.private_ip
    grafana_admin_password = local.grafana_password
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-observability"
  })
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = local.cloudtrail_bucket_name
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = local.cloudtrail_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "cloudtrail-retention"
    status = "Enabled"

    filter {}

    expiration {
      days = var.cloudtrail_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.cloudtrail_retention_days
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_s3_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_s3_policy.json
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  depends_on = [aws_s3_bucket_policy.cloudtrail]

  tags = local.common_tags
}

resource "aws_guardduty_detector" "main" {
  enable = true

  tags = local.common_tags
}
