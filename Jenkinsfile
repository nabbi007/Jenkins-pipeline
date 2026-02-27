pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    parallelsAlwaysFailFast()
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
    string(name: 'BACKEND_LOG_GROUP', defaultValue: '/project/backend', description: 'CloudWatch Logs group for backend container')
    string(name: 'FRONTEND_LOG_GROUP', defaultValue: '/project/frontend', description: 'CloudWatch Logs group for frontend container')
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
          env.BACKEND_LOG_GROUP_EFFECTIVE = params.BACKEND_LOG_GROUP?.trim() ? params.BACKEND_LOG_GROUP.trim() : '/project/backend'
          env.FRONTEND_LOG_GROUP_EFFECTIVE = params.FRONTEND_LOG_GROUP?.trim() ? params.FRONTEND_LOG_GROUP.trim() : '/project/frontend'

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

    stage('Shift Left - Lint/Test/Build') {
      parallel {
        stage('Backend Lint/Test/SAST') {
          steps {
            dir('backend') {
              sh 'npm install --no-audit --no-fund'
              sh 'npm run lint'
              sh 'npm run test:ci'
              sh 'npm audit --audit-level=high --omit=dev'
            }
          }
        }
        stage('Frontend Lint/Test/Build') {
          steps {
            dir('frontend') {
              sh 'npm install --no-audit --no-fund'
              sh 'npm run lint'
              sh 'npm run test:ci'
              sh 'npm run build'
            }
          }
        }
      }
    }
    
    stage('Docker Build') {
      parallel {
        stage('Build Backend Image') {
          steps {
            dir('backend') {
              sh '''
                export DOCKER_BUILDKIT=1
                docker build -t "$BACKEND_IMAGE_URI" .
              '''
            }
          }
        }
        stage('Build Frontend Image') {
          steps {
            dir('frontend') {
              sh '''
                export DOCKER_BUILDKIT=1
                docker build -t "$FRONTEND_IMAGE_URI" .
              '''
            }
          }
        }
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
            set -euo pipefail

            cat > deploy.env <<EOF
BACKEND_IMAGE=$BACKEND_IMAGE_URI
FRONTEND_IMAGE=$FRONTEND_IMAGE_URI
AWS_REGION=$AWS_REGION
BACKEND_LOG_GROUP=$BACKEND_LOG_GROUP_EFFECTIVE
FRONTEND_LOG_GROUP=$FRONTEND_LOG_GROUP_EFFECTIVE
EOF

            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$DEPLOY_HOST_EFFECTIVE "mkdir -p ~/app-deploy"
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no docker-compose.deploy.yml ec2-user@$DEPLOY_HOST_EFFECTIVE:~/app-deploy/docker-compose.yml
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no deploy.env ec2-user@$DEPLOY_HOST_EFFECTIVE:~/app-deploy/.env

            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$DEPLOY_HOST_EFFECTIVE "
              set -euo pipefail
              cd ~/app-deploy
              aws ecr get-login-password --region '$AWS_REGION' | docker login --username AWS --password-stdin '$ECR_REGISTRY'
              EXPECTED_PROJECT=\"\$(basename \"\$PWD\")\"

              # One-time migration guard:
              # remove legacy containers that use the same fixed names but are not managed by this compose project.
              for c in frontend backend redis redis-exporter; do
                if docker ps -a --format '{{.Names}}' | grep -qx \"\$c\"; then
                  project_label=\"\$(docker inspect -f '{{ index .Config.Labels \"com.docker.compose.project\" }}' \"\$c\" 2>/dev/null || true)\"
                  if [ \"\$project_label\" != \"\$EXPECTED_PROJECT\" ]; then
                    docker rm -f \"\$c\" >/dev/null 2>&1 || true
                  fi
                fi
              done

              if docker compose version >/dev/null 2>&1; then
                docker compose up -d --pull always --remove-orphans
              elif command -v docker-compose >/dev/null 2>&1; then
                docker-compose up -d --pull always --remove-orphans
              else
                echo 'Docker Compose not found on target host; installing standalone binary...'
                sudo curl -fsSL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
                if command -v docker-compose >/dev/null 2>&1; then
                  docker-compose up -d --pull always --remove-orphans
                else
                  echo 'Docker Compose installation failed on target host' >&2
                  exit 1
                fi
              fi

              docker image prune -f || true
            "

            rm -f deploy.env
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
    }
  }
}
