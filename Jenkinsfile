// ============================================================
// Jenkinsfile — TechPathway Full-Stack CI/CD Pipeline
// ============================================================
// Prerequisites on Jenkins server:
//   - Docker installed and Jenkins user in docker group
//   - AWS CLI v2 installed
//   - aws-credentials plugin configured (id: 'aws-credentials')
//   - Jenkins EC2 instance has IAM role with ECR + ECS permissions
// ============================================================

pipeline {
    agent any

    // ── Environment variables ─────────────────────────────────
    environment {
        AWS_REGION          = 'us-east-1'
        AWS_ACCOUNT_ID      = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
        ECR_REGISTRY        = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        PROJECT_NAME        = 'techpathway'

        FRONTEND_REPO       = "${ECR_REGISTRY}/${PROJECT_NAME}-frontend"
        BACKEND_REPO        = "${ECR_REGISTRY}/${PROJECT_NAME}-backend"

        ECS_CLUSTER         = "${PROJECT_NAME}-cluster"
        FRONTEND_SERVICE    = "${PROJECT_NAME}-frontend-service"
        BACKEND_SERVICE     = "${PROJECT_NAME}-backend-service"
        FRONTEND_TASK_FAMILY = "${PROJECT_NAME}-frontend"
        BACKEND_TASK_FAMILY  = "${PROJECT_NAME}-backend"

        IMAGE_TAG           = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
    }

    // ── Trigger: poll SCM every minute (or use GitHub webhook) ─
    triggers {
        pollSCM('H/1 * * * *')
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        // ────────────────────────────────────────────────────────
        stage('🔍 Checkout') {
        // ────────────────────────────────────────────────────────
            steps {
                echo "Checking out branch: ${env.BRANCH_NAME ?: 'main'}"
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        // ────────────────────────────────────────────────────────
        stage('🔐 ECR Login') {
        // ────────────────────────────────────────────────────────
            steps {
                sh '''
                    aws ecr get-login-password --region $AWS_REGION \
                        | docker login --username AWS --password-stdin $ECR_REGISTRY
                    echo "✅ Logged in to ECR: $ECR_REGISTRY"
                '''
            }
        }

        // ────────────────────────────────────────────────────────
        stage('🏗️ Build Images') {
        // ────────────────────────────────────────────────────────
            parallel {

                stage('Build Backend') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "Building backend image: $BACKEND_REPO:$IMAGE_TAG"
                                docker build \
                                    -f ../Dockerfile.backend \
                                    -t $BACKEND_REPO:$IMAGE_TAG \
                                    -t $BACKEND_REPO:latest \
                                    .
                                echo "✅ Backend image built"
                            '''
                        }
                    }
                }

                stage('Build Frontend') {
                    steps {
                        script {
                            // Get the ALB DNS from Terraform outputs (or use a known value)
                            def albDns = sh(
                                script: "aws elbv2 describe-load-balancers --names ${PROJECT_NAME}-alb --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo ''",
                                returnStdout: true
                            ).trim()

                            def backendUrl = albDns ? "http://${albDns}/api" : 'http://localhost:8080'
                            echo "Using backend URL: ${backendUrl}"

                            dir('frontend') {
                                sh """
                                    echo "Building frontend image: $FRONTEND_REPO:$IMAGE_TAG"
                                    docker build \\
                                        -f ../Dockerfile.frontend \\
                                        --build-arg REACT_APP_BACKEND_URL=${backendUrl} \\
                                        -t $FRONTEND_REPO:$IMAGE_TAG \\
                                        -t $FRONTEND_REPO:latest \\
                                        .
                                    echo "✅ Frontend image built"
                                """
                            }
                        }
                    }
                }
            }
        }

        // ────────────────────────────────────────────────────────
        stage('🚀 Push to ECR') {
        // ────────────────────────────────────────────────────────
            parallel {

                stage('Push Backend') {
                    steps {
                        sh '''
                            docker push $BACKEND_REPO:$IMAGE_TAG
                            docker push $BACKEND_REPO:latest
                            echo "✅ Backend pushed to ECR"
                        '''
                    }
                }

                stage('Push Frontend') {
                    steps {
                        sh '''
                            docker push $FRONTEND_REPO:$IMAGE_TAG
                            docker push $FRONTEND_REPO:latest
                            echo "✅ Frontend pushed to ECR"
                        '''
                    }
                }
            }
        }

        // ────────────────────────────────────────────────────────
        stage('📝 Register New Task Definitions') {
        // ────────────────────────────────────────────────────────
            steps {
                script {
                    // ── Backend Task Definition ──────────────────
                    def backendTask = sh(
                        script: """
                            aws ecs describe-task-definition \
                                --task-definition $BACKEND_TASK_FAMILY \
                                --query 'taskDefinition' \
                                --output json
                        """,
                        returnStdout: true
                    ).trim()

                    def backendJson = readJSON text: backendTask
                    backendJson.containerDefinitions[0].image = "${env.BACKEND_REPO}:${env.IMAGE_TAG}"

                    // Remove fields not accepted by register-task-definition
                    ['taskDefinitionArn','revision','status','requiresAttributes',
                     'compatibilities','registeredAt','registeredBy'].each { key ->
                        backendJson.remove(key)
                    }

                    writeJSON file: '/tmp/backend-task-def.json', json: backendJson
                    sh '''
                        aws ecs register-task-definition \
                            --cli-input-json file:///tmp/backend-task-def.json \
                            --region $AWS_REGION
                        echo "✅ Backend task definition registered"
                    '''

                    // ── Frontend Task Definition ─────────────────
                    def frontendTask = sh(
                        script: """
                            aws ecs describe-task-definition \
                                --task-definition $FRONTEND_TASK_FAMILY \
                                --query 'taskDefinition' \
                                --output json
                        """,
                        returnStdout: true
                    ).trim()

                    def frontendJson = readJSON text: frontendTask
                    frontendJson.containerDefinitions[0].image = "${env.FRONTEND_REPO}:${env.IMAGE_TAG}"

                    ['taskDefinitionArn','revision','status','requiresAttributes',
                     'compatibilities','registeredAt','registeredBy'].each { key ->
                        frontendJson.remove(key)
                    }

                    writeJSON file: '/tmp/frontend-task-def.json', json: frontendJson
                    sh '''
                        aws ecs register-task-definition \
                            --cli-input-json file:///tmp/frontend-task-def.json \
                            --region $AWS_REGION
                        echo "✅ Frontend task definition registered"
                    '''
                }
            }
        }

        // ────────────────────────────────────────────────────────
        stage('🔄 Deploy to ECS') {
        // ────────────────────────────────────────────────────────
            steps {
                sh '''
                    # Get latest revision numbers
                    BACKEND_REVISION=$(aws ecs describe-task-definition \
                        --task-definition $BACKEND_TASK_FAMILY \
                        --query 'taskDefinition.revision' \
                        --output text)

                    FRONTEND_REVISION=$(aws ecs describe-task-definition \
                        --task-definition $FRONTEND_TASK_FAMILY \
                        --query 'taskDefinition.revision' \
                        --output text)

                    echo "Deploying backend revision: $BACKEND_REVISION"
                    aws ecs update-service \
                        --cluster $ECS_CLUSTER \
                        --service $BACKEND_SERVICE \
                        --task-definition $BACKEND_TASK_FAMILY:$BACKEND_REVISION \
                        --force-new-deployment \
                        --region $AWS_REGION
                    echo "✅ Backend service updated"

                    echo "Deploying frontend revision: $FRONTEND_REVISION"
                    aws ecs update-service \
                        --cluster $ECS_CLUSTER \
                        --service $FRONTEND_SERVICE \
                        --task-definition $FRONTEND_TASK_FAMILY:$FRONTEND_REVISION \
                        --force-new-deployment \
                        --region $AWS_REGION
                    echo "✅ Frontend service updated"
                '''
            }
        }

        // ────────────────────────────────────────────────────────
        stage('⏳ Wait for Stable Deployment') {
        // ────────────────────────────────────────────────────────
            steps {
                sh '''
                    echo "Waiting for backend service to stabilise..."
                    aws ecs wait services-stable \
                        --cluster $ECS_CLUSTER \
                        --services $BACKEND_SERVICE \
                        --region $AWS_REGION
                    echo "✅ Backend service is stable"

                    echo "Waiting for frontend service to stabilise..."
                    aws ecs wait services-stable \
                        --cluster $ECS_CLUSTER \
                        --services $FRONTEND_SERVICE \
                        --region $AWS_REGION
                    echo "✅ Frontend service is stable"
                '''
            }
        }

        // ────────────────────────────────────────────────────────
        stage('🧪 Smoke Test') {
        // ────────────────────────────────────────────────────────
            steps {
                script {
                    def albDns = sh(
                        script: "aws elbv2 describe-load-balancers --names ${PROJECT_NAME}-alb --query 'LoadBalancers[0].DNSName' --output text",
                        returnStdout: true
                    ).trim()

                    sh """
                        echo "Running smoke tests against: http://${albDns}"

                        # Test frontend is reachable
                        HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://${albDns}/)
                        if [ "\$HTTP_STATUS" != "200" ]; then
                            echo "❌ Frontend smoke test FAILED (HTTP \$HTTP_STATUS)"
                            exit 1
                        fi
                        echo "✅ Frontend responded with HTTP 200"

                        # Test backend health endpoint
                        HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://${albDns}/api/health)
                        if [ "\$HTTP_STATUS" != "200" ]; then
                            echo "❌ Backend health check FAILED (HTTP \$HTTP_STATUS)"
                            exit 1
                        fi
                        echo "✅ Backend health check responded with HTTP 200"

                        echo ""
                        echo "🎉 All smoke tests PASSED"
                        echo "Frontend URL: http://${albDns}"
                    """
                }
            }
        }
    }

    // ── Post-build actions ────────────────────────────────────
    post {
        always {
            // Clean up local Docker images to save disk space
            sh '''
                docker rmi $BACKEND_REPO:$IMAGE_TAG || true
                docker rmi $FRONTEND_REPO:$IMAGE_TAG || true
                docker system prune -f || true
            '''
        }

        success {
            echo """
            ╔═══════════════════════════════════════╗
            ║   ✅ PIPELINE SUCCEEDED                ║
            ║   Build:    #${BUILD_NUMBER}             ║
            ║   Commit:   ${GIT_COMMIT.take(7)}        ║
            ╚═══════════════════════════════════════╝
            """
        }

        failure {
            echo """
            ╔═══════════════════════════════════════╗
            ║   ❌ PIPELINE FAILED                   ║
            ║   Build:    #${BUILD_NUMBER}             ║
            ╚═══════════════════════════════════════╝
            """
        }

        cleanup {
            cleanWs()
        }
    }
}
