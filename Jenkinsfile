pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  triggers {
    githubPush()
  }

  parameters {
    string(name: 'AWS_REGION', defaultValue: 'eu-west-1', description: 'AWS region containing ECR and EC2')
    string(name: 'ECR_ACCOUNT_ID', defaultValue: '', description: 'AWS account ID used for ECR URI')
    string(name: 'BACKEND_ECR_REPO', defaultValue: 'backend-service', description: 'ECR repository for backend image')
    string(name: 'FRONTEND_ECR_REPO', defaultValue: 'frontend-web', description: 'ECR repository for frontend image')
    string(name: 'DEPLOY_HOST', defaultValue: '', description: 'EC2 public IP to deploy to. Leave blank to auto-detect from instance metadata (handles dynamic IPs on restart).')
    booleanParam(name: 'ENABLE_SONARQUBE', defaultValue: true, description: 'Run SonarQube scan when scanner + credentials are available')
    booleanParam(name: 'ENABLE_TRIVY', defaultValue: true, description: 'Run container vulnerability scan when trivy is installed')
  }

  environment {
    BACKEND_LOG_GROUP = '/project/backend'
    FRONTEND_LOG_GROUP = '/project/frontend'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Prepare Metadata') {
      steps {
        script {
          env.GIT_SHA = sh(script: 'git rev-parse --short=8 HEAD', returnStdout: true).trim()
          env.SAFE_BRANCH = env.BRANCH_NAME.replaceAll('[^a-zA-Z0-9_.-]', '-')
          env.IMAGE_TAG = "${env.SAFE_BRANCH}-${env.GIT_SHA}-${env.BUILD_NUMBER}"

          if (!params.ECR_ACCOUNT_ID?.trim()) {
            env.ECR_ACCOUNT_ID_EFFECTIVE = sh(
              script: 'aws sts get-caller-identity --query Account --output text',
              returnStdout: true
            ).trim()
            if (!env.ECR_ACCOUNT_ID_EFFECTIVE) {
              error('Could not determine AWS account ID. Ensure the EC2 IAM role has sts:GetCallerIdentity permission.')
            }
          } else {
            env.ECR_ACCOUNT_ID_EFFECTIVE = params.ECR_ACCOUNT_ID.trim()
          }
          env.ECR_REGISTRY = "${env.ECR_ACCOUNT_ID_EFFECTIVE}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
          env.BACKEND_IMAGE_URI = "${env.ECR_ACCOUNT_ID_EFFECTIVE}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/${params.BACKEND_ECR_REPO}:${env.IMAGE_TAG}"
          env.FRONTEND_IMAGE_URI = "${env.ECR_ACCOUNT_ID_EFFECTIVE}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/${params.FRONTEND_ECR_REPO}:${env.IMAGE_TAG}"

          // Resolve deploy host — Jenkins and app run on the same EC2 instance.
          // Always fetch the current public IP from instance metadata so the pipeline
          // works correctly after a stop/start (which changes the public IP).
          if (!params.DEPLOY_HOST?.trim()) {
            def imdsToken = sh(
              script: 'curl -sf -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"',
              returnStdout: true
            ).trim()
            env.DEPLOY_HOST_EFFECTIVE = sh(
              script: "curl -sf -H 'X-aws-ec2-metadata-token: ${imdsToken}' http://169.254.169.254/latest/meta-data/public-ipv4",
              returnStdout: true
            ).trim()
            if (!env.DEPLOY_HOST_EFFECTIVE) {
              error('Could not fetch public IP from EC2 instance metadata. Ensure the instance has a public IP and IMDSv2 is enabled.')
            }
            echo "Resolved DEPLOY_HOST from instance metadata: ${env.DEPLOY_HOST_EFFECTIVE}"
          } else {
            env.DEPLOY_HOST_EFFECTIVE = params.DEPLOY_HOST.trim()
            echo " DEPLOY_HOST: ${env.DEPLOY_HOST_EFFECTIVE}"
          }
        }
      }
    }

    stage('Shift Left - Backend Lint/Test/SAST') {
      steps {
        dir('backend') {
          sh 'npm install --no-audit --no-fund'
          sh 'npm run lint'
          sh 'npm run test:ci'
          sh 'npm audit --audit-level=high --omit=dev'
        }
      }
    }

    stage('Shift Left - Frontend Lint/Test/Build') {
      steps {
        dir('frontend') {
          sh 'npm install --no-audit --no-fund'
          sh 'npm run lint'
          sh 'npm run test:ci'
          sh 'npm run build'
        }
      }
    }
    
    stage('Docker Build') {
      steps {
        sh 'docker build -t "$BACKEND_IMAGE_URI" backend'
        sh 'docker build -t "$FRONTEND_IMAGE_URI" frontend'
      }
    }

    stage('Push Image To ECR') {
      steps {
        sh '''
          aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
          docker push "$BACKEND_IMAGE_URI"
          docker push "$FRONTEND_IMAGE_URI"
        '''
      }
    }

    stage('Deploy To EC2') {
      when {
        allOf {
          branch 'main'
          expression { return env.DEPLOY_HOST_EFFECTIVE?.trim() }
        }
      }
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ec2_ssh', keyFileVariable: 'SSH_KEY')]) {
          sh '''
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no scripts/deploy_backend.sh ec2-user@$DEPLOY_HOST_EFFECTIVE:/tmp/deploy_backend.sh
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no scripts/deploy_frontend.sh ec2-user@$DEPLOY_HOST_EFFECTIVE:/tmp/deploy_frontend.sh
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$DEPLOY_HOST_EFFECTIVE "chmod +x /tmp/deploy_backend.sh /tmp/deploy_frontend.sh"
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$DEPLOY_HOST_EFFECTIVE "/tmp/deploy_backend.sh '$AWS_REGION' '$ECR_ACCOUNT_ID_EFFECTIVE' '$BACKEND_ECR_REPO' '$IMAGE_TAG' '$BACKEND_LOG_GROUP'"
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$DEPLOY_HOST_EFFECTIVE "/tmp/deploy_frontend.sh '$AWS_REGION' '$ECR_ACCOUNT_ID_EFFECTIVE' '$FRONTEND_ECR_REPO' '$IMAGE_TAG' '$FRONTEND_LOG_GROUP'"
          '''
        }
      }
    }

    stage('Cleanup') {
      steps {
        sh 'docker image prune -f || true'
      }
    }
  }

  post {
    always {
      echo "Build result: ${currentBuild.currentResult}"
    }
    success {
      echo "Image tag: ${env.IMAGE_TAG}"
      echo "Backend image: ${env.BACKEND_IMAGE_URI}"
      echo "Frontend image: ${env.FRONTEND_IMAGE_URI}"
      script {
        if (env.DEPLOY_HOST_EFFECTIVE?.trim()) {
          echo "============================================"
          echo "App URL:     http://${env.DEPLOY_HOST_EFFECTIVE}"
          echo "Backend API: http://${env.DEPLOY_HOST_EFFECTIVE}:3000/api/health"
          echo "Metrics:     http://${env.DEPLOY_HOST_EFFECTIVE}:3000/metrics"
          echo "Jenkins:     http://${env.DEPLOY_HOST_EFFECTIVE}:8080"
          echo "============================================"
        }
      }
    }
  }
}
