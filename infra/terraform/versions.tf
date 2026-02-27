terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "jenkins-app-hardening"
    key            = "jenkins-project/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    use_lockfile   = true 
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
