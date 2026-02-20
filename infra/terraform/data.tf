data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Get default VPC if no subnet_id provided.
data "aws_vpc" "default" {
  default = true
}

# Auto-select first public subnet from default VPC if subnet_id not provided.
data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

locals {
  # Use provided subnet_id or first auto-discovered public subnet.
  effective_subnet_id = coalesce(var.subnet_id, try(data.aws_subnets.default_public.ids[0], null))
}

data "aws_subnet" "selected" {
  id = local.effective_subnet_id
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
