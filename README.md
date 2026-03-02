# TechPathway DevOps Deployment

> Full-Stack deployment of a React + Express app using Jenkins, Docker, AWS ECS, ECR, and Terraform.

---

## Architecture Overview

```
Internet
   │
   ▼
[Application Load Balancer]  ← public, port 80
   │               │
   │ /             │ /api/*
   ▼               ▼
[Frontend ECS]  [Backend ECS]   ← private subnets, Fargate
(React/Nginx)   (Express/Node)
   │               │
   └───────────────┘
         ▼
   [ECR Repositories]
   [CloudWatch Logs]
```

**Traffic flow:**
- `http://<ALB_DNS>/` → Frontend React app (Nginx)
- `http://<ALB_DNS>/api/*` → Backend Express API
- CORS is handled automatically — frontend and backend share the same ALB domain

---

## AWS Resources

### Jenkins Server (manual EC2)
| Resource | Details |
|---|---|
| EC2 Instance | `t3.medium`, Amazon Linux 2023 or Ubuntu 22.04 |
| Security Group | Port 8080 (Jenkins UI), Port 22 (SSH) |
| IAM Role | `techpathway-jenkins-role` — ECR push + ECS update permissions |
| EIP | Static public IP for Jenkins access |

### Terraform-managed Infrastructure
| Resource | Purpose |
|---|---|
| VPC | Isolated network `10.0.0.0/16` |
| Public Subnets (×2) | ALB + NAT Gateway |
| Private Subnets (×2) | ECS Fargate tasks |
| Internet Gateway | Public internet access |
| NAT Gateway | Outbound internet for private subnets |
| ALB | Single public entry point, path-based routing |
| ECS Cluster | Fargate cluster with Container Insights |
| ECS Task Definitions | Frontend + Backend task specs |
| ECS Services | Self-healing task management |
| ECR Repositories | `techpathway-frontend`, `techpathway-backend` |
| CloudWatch Log Groups | `/ecs/techpathway/frontend`, `/ecs/techpathway/backend` |
| IAM Roles | Task execution role, task runtime role, Jenkins role |
| Security Groups | ALB, frontend tasks, backend tasks, Jenkins |

---

## Quick Start

### 1. Prerequisites

- AWS account with admin access
- Terraform ≥ 1.5
- AWS CLI v2 configured (`aws configure`)
- Docker
- Git

### 2. Clone the repository

```bash
git clone https://github.com/pakurumo/techpathway-2
cd techpathway-2
```

Copy the DevOps files from this repo into the cloned project:
```bash
cp -r /path/to/devops-files/* .
```

### 3. Run Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed

terraform init
terraform plan
terraform apply
```

Note the outputs — you'll need:
- `frontend_ecr_url`
- `backend_ecr_url`
- `alb_dns_name`
- `ecs_cluster_name`

### 4. Launch Jenkins Server

**Launch EC2 manually (or use Terraform):**
- AMI: Amazon Linux 2023 or Ubuntu 22.04
- Instance type: `t3.medium`
- IAM Instance Profile: `techpathway-jenkins-instance-profile` (created by Terraform)
- Security Group: `techpathway-jenkins-sg`
- Storage: 30 GB gp3

**Bootstrap Jenkins:**
```bash
# SSH into the EC2 instance
ssh -i your-key.pem ec2-user@<JENKINS_PUBLIC_IP>

# Upload and run the setup script
sudo bash jenkins-setup.sh
```

**Access Jenkins:** `http://<JENKINS_PUBLIC_IP>:8080`

Get initial password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 5. Configure Jenkins

1. Install suggested plugins + additional:
   - **Pipeline**
   - **Git**
   - **Docker Pipeline**
   - **AWS Credentials**
   - **Pipeline: AWS Steps**

2. Create a new Pipeline job:
   - New Item → Pipeline → Name: `techpathway-deploy`
   - Definition: Pipeline script from SCM
   - SCM: Git → your repo URL
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

3. Run the pipeline — it will build, push, and deploy automatically.

### 6. Place app-specific files

Copy config patches into the cloned app repo:

```bash
# Frontend: replace src/config.js
cp frontend-config.js frontend/src/config.js

# Backend: replace config.js
cp backend-config.js backend/config.js

# Dockerfiles: place at root of repo
cp docker/Dockerfile.backend ./Dockerfile.backend
cp docker/Dockerfile.frontend ./Dockerfile.frontend
cp docker/nginx.conf ./nginx.conf
```

---

## Local Development

Test the full stack locally with Docker Compose:

```bash
docker-compose up --build
```

- Frontend: http://localhost:3000
- Backend: http://localhost:8080/health

Without Docker (native):

```bash
# Terminal 1 — Backend
cd backend && npm ci && npm start

# Terminal 2 — Frontend
cd frontend && npm ci && npm start
```

If working correctly, the frontend shows **SUCCESS** and a GUID.

---

## CI/CD Pipeline Stages

```
1. 🔍 Checkout        → pull latest code from GitHub
2. 🔐 ECR Login       → authenticate Docker with ECR
3. 🏗️ Build Images    → build frontend & backend Docker images (parallel)
4. 🚀 Push to ECR     → push versioned + latest tags (parallel)
5. 📝 Register Tasks  → create new ECS task definition revisions
6. 🔄 Deploy to ECS   → force-update ECS services
7. ⏳ Wait Stable     → wait until both services stabilise
8. 🧪 Smoke Test      → verify frontend and backend are responding
```

The pipeline runs end-to-end without any manual steps once triggered.

---

## Configuration Files

| File | Purpose |
|---|---|
| `frontend/src/config.js` | Sets `backendUrl` — reads from `REACT_APP_BACKEND_URL` env var |
| `backend/config.js` | Sets CORS allowed origin — reads from `CORS_ORIGIN` env var |
| `Jenkinsfile` | Full CI/CD pipeline definition |
| `Dockerfile.backend` | Multi-stage Node.js production image |
| `Dockerfile.frontend` | Multi-stage React build + Nginx serve |
| `nginx.conf` | Nginx config with SPA routing and caching |
| `terraform/` | All infrastructure-as-code |

---

## Environment Variables

### Backend (set in ECS Task Definition)
| Variable | Example | Description |
|---|---|---|
| `NODE_ENV` | `production` | Node environment |
| `PORT` | `8080` | Port to listen on |
| `CORS_ORIGIN` | `http://my-alb.elb.amazonaws.com` | Allowed CORS origin |

### Frontend (set at Docker build time)
| Variable | Example | Description |
|---|---|---|
| `REACT_APP_BACKEND_URL` | `http://my-alb.elb.amazonaws.com/api` | Backend API base URL |

---

## Terraform Commands Reference

```bash
cd terraform

# Initialise (first time)
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy all infrastructure
terraform destroy

# Show outputs
terraform output
```

---

## Security Notes

- ECS tasks run in **private subnets** — not directly reachable from the internet
- All public traffic goes through the **ALB**
- Backend is only accessible via the ALB `/api/*` rule, not directly exposed
- Jenkins SSH access should be restricted to your IP (`0.0.0.0/0` is only for testing)
- Terraform state should be stored in S3 with DynamoDB locking (see commented config in `provider.tf`)
- ECR images are scanned on push for vulnerabilities

---

## Submission Checklist

- [ ] Screenshot: deployed frontend showing SUCCESS + GUID
- [ ] Screenshot: Jenkins pipeline showing all stages green
- [ ] GitHub repo link (contains Terraform, Dockerfiles, Jenkinsfile)
- [ ] Public URL: `http://<ALB_DNS>`
- [ ] Jenkins URL: `http://<JENKINS_IP>:8080` + login details
- [ ] Short test/deploy instructions (see Quick Start above)
