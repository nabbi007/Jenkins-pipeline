pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '20'))
  }

  parameters {
    string(name: 'AWS_REGION', defaultValue: 'eu-west-1', description: 'AWS region containing ECR and EC2')
    string(name: 'ECR_ACCOUNT_ID', defaultValue: '', description: 'AWS account ID used for ECR URI')
    string(name: 'BACKEND_ECR_REPO', defaultValue: 'backend-service', description: 'ECR repository for backend image')
    string(name: 'FRONTEND_ECR_REPO', defaultValue: 'frontend-web', description: 'ECR repository for frontend image')
    string(name: 'DEPLOY_HOST', defaultValue: '', description: 'EC2 public IP or DNS where app is deployed. Set once via Build with Parameters, then save the branch config to persist it.')
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
            // Auto-detect AWS account ID from the instance's IAM role — no manual input needed.
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

    stage('SonarQube Scan') {
      when {
        expression { return params.ENABLE_SONARQUBE }
      }
      steps {
        script {
          if (sh(script: 'command -v sonar-scanner >/dev/null 2>&1', returnStatus: true) != 0) {
            echo 'sonar-scanner is not installed on this Jenkins agent. Skipping SonarQube stage.'
            return
          }

          try {
            withCredentials([string(credentialsId: 'sonarqube_token', variable: 'SONAR_TOKEN')]) {
              sh '''
                sonar-scanner \
                  -Dsonar.projectKey=jenkins-project \
                  -Dsonar.projectName=jenkins-project \
                  -Dsonar.sources=backend/src,frontend/src \
                  -Dsonar.tests=backend/tests,frontend/tests \
                  -Dsonar.host.url=${SONAR_HOST_URL:-http://localhost:9000} \
                  -Dsonar.token=$SONAR_TOKEN
              '''
            }
          } catch (Exception ex) {
            echo "Skipping SonarQube scan: ${ex.getMessage()}"
          }
        }
      }
    }

    stage('Docker Build') {
      steps {
        sh 'docker build -t "$BACKEND_IMAGE_URI" backend'
        sh 'docker build -t "$FRONTEND_IMAGE_URI" frontend'
      }
    }

    stage('Container Security Scan') {
      when {
        expression { return params.ENABLE_TRIVY }
      }
      steps {
        script {
          if (sh(script: 'command -v trivy >/dev/null 2>&1', returnStatus: true) != 0) {
            echo 'trivy is not installed on this Jenkins agent. Skipping image security scan.'
            return
          }

          sh 'trivy image --severity HIGH,CRITICAL --exit-code 1 "$BACKEND_IMAGE_URI"'
          sh 'trivy image --severity HIGH,CRITICAL --exit-code 1 "$FRONTEND_IMAGE_URI"'
        }
      }
    }

    stage('Push Image To ECR') {
      steps {
        // Use the EC2 IAM role directly — no stored AWS credentials needed.
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
          expression { return params.DEPLOY_HOST?.trim() }
        }
      }
      steps {
        sshagent(credentials: ['ec2_ssh']) {
          sh '''
            scp -o StrictHostKeyChecking=no scripts/deploy_backend.sh ec2-user@$DEPLOY_HOST:/tmp/deploy_backend.sh
            scp -o StrictHostKeyChecking=no scripts/deploy_frontend.sh ec2-user@$DEPLOY_HOST:/tmp/deploy_frontend.sh
            ssh -o StrictHostKeyChecking=no ec2-user@$DEPLOY_HOST "chmod +x /tmp/deploy_backend.sh /tmp/deploy_frontend.sh"
            ssh -o StrictHostKeyChecking=no ec2-user@$DEPLOY_HOST "/tmp/deploy_backend.sh '$AWS_REGION' '$ECR_ACCOUNT_ID_EFFECTIVE' '$BACKEND_ECR_REPO' '$IMAGE_TAG' '$BACKEND_LOG_GROUP'"
            ssh -o StrictHostKeyChecking=no ec2-user@$DEPLOY_HOST "/tmp/deploy_frontend.sh '$AWS_REGION' '$ECR_ACCOUNT_ID_EFFECTIVE' '$FRONTEND_ECR_REPO' '$IMAGE_TAG' '$FRONTEND_LOG_GROUP'"
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
        if (params.DEPLOY_HOST?.trim()) {
          echo "============================================"
          echo "App URL:     http://${params.DEPLOY_HOST}"
          echo "Backend API: http://${params.DEPLOY_HOST}:3000/api/health"
          echo "Metrics:     http://${params.DEPLOY_HOST}:3000/metrics"
          echo "Jenkins:     http://${params.DEPLOY_HOST}:8080"
          echo "============================================"
        }
      }
    }
  }
}
