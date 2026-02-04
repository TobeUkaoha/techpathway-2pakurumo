pipeline {
agent any

environment {
AWS_ACCOUNT_ID = '363934772067'
REGION = 'us-east-1'

ECR_REPO_BACKEND = 'tech-backend'
ECR_REPO_FRONTEND = 'tech-frontend'

CLUSTER_NAME = 'techpathway-cluster'
BACKEND_SERVICE = 'backend-service'
FRONTEND_SERVICE = 'frontend-service'
}

stages {

stage('Terraform Init & Apply') {
steps {
dir('terraform') {
sh '''
terraform init
terraform validate
terraform apply -auto-approve
'''
}
}
}

stage('Build Backend Docker Image') {
steps {
dir('backend') {
sh '''
docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_BACKEND}:latest .
'''
}
}
}

stage('Build Frontend Docker Image') {
steps {
dir('frontend') {
sh '''
docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_FRONTEND}:latest .
'''
}
}
}

stage('Push Images to ECR') {
steps {
sh '''
aws ecr get-login-password --region ${REGION} | \
docker login --username AWS --password-stdin \
${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_BACKEND}:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_FRONTEND}:latest
'''
}
}

stage('Deploy to ECS') {
steps {
sh '''
aws ecs update-service \
--cluster ${CLUSTER_NAME} \
--service ${BACKEND_SERVICE} \
--force-new-deployment

aws ecs update-service \
--cluster ${CLUSTER_NAME} \
--service ${FRONTEND_SERVICE} \
--force-new-deployment
'''
}
}
}

post {
success {
echo '✅ Full CI/CD pipeline completed successfully'
}
failure {
echo '❌ Pipeline failed — check Jenkins logs'
}
}
}

