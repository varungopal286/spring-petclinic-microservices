# Spring PetClinic Microservices — AWS EKS Capstone Deployment

[![Build and Deploy to EKS](https://github.com/varungopal286/spring-petclinic-microservices/actions/workflows/deploy.yml/badge.svg)](https://github.com/varungopal286/spring-petclinic-microservices/actions/workflows/deploy.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A production-style deployment of the [Spring PetClinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices) application on **AWS EKS** using Terraform, Helm, GitHub Actions CI/CD, and Prometheus/Grafana monitoring.

---

## Architecture

```
Internet
    │
    ▼
AWS ALB (internet-facing)
    │
    ▼
api-gateway  (:8080)
    │
    ├──► customers-service (:8081) ──► MySQL 8.0 (EBS PVC)
    ├──► vets-service       (:8083) ──► MySQL 8.0 (EBS PVC)
    └──► visits-service     (:8082) ──► MySQL 8.0 (EBS PVC)

All services ──► config-server   (:8888)  [Spring Cloud Config → GitHub]
All services ──► discovery-server(:8761)  [Spring Cloud Eureka]
```

### Infrastructure Stack

| Layer | Technology |
|---|---|
| Cloud | AWS (ap-south-1 / Mumbai) |
| Container Orchestration | Amazon EKS 1.32 |
| Infrastructure as Code | Terraform (S3 remote state) |
| Container Registry | Amazon ECR |
| Ingress | AWS ALB Ingress Controller |
| Packaging | Helm 3 |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) |
| Database | MySQL 8.0 on Kubernetes (EBS gp2 PVC) |

### Startup Order (enforced by Helm init containers)

```
config-server → discovery-server → customers/vets/visits/api-gateway
```

Each pod uses a busybox init container with `nc -z` TCP checks to wait for its dependencies before starting.

---

## Prerequisites

- AWS CLI configured with an IAM user that has EKS/ECR/IAM permissions
- Terraform >= 1.5
- kubectl
- Helm >= 3.12
- Java 17 + Maven (for local Docker builds)
- Docker with Buildx

---

## Day-by-Day Deployment Guide

### Day 1 — Local Setup & Verification

```bash
# Clone the repo
git clone https://github.com/varungopal286/spring-petclinic-microservices.git
cd spring-petclinic-microservices

# Run all services locally
docker compose up

# Verify: http://localhost:8080
```

### Day 2 — AWS Infrastructure with Terraform

```bash
# Create S3 backend + DynamoDB lock table manually, then:
cd terraform
terraform init
terraform plan
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name petclinic-cluster --region ap-south-1

# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=petclinic-cluster \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<ALB_ROLE_ARN>

# Install EBS CSI Driver (required for PVC provisioning on EKS 1.23+)
aws eks create-addon --cluster-name petclinic-cluster \
  --addon-name aws-ebs-csi-driver --region ap-south-1

# Build and push Docker images
cat > /tmp/docker-wrapper << 'EOF'
#!/bin/bash
if [ "$1" = "build" ]; then
  shift
  exec docker buildx build "$@"
else
  exec docker "$@"
fi
EOF
chmod +x /tmp/docker-wrapper

./mvnw clean install -P buildDocker -DskipTests \
  -Dcontainer.executable=/tmp/docker-wrapper

ECR="622215956811.dkr.ecr.ap-south-1.amazonaws.com"
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin $ECR

for svc in config-server discovery-server customers-service vets-service visits-service api-gateway; do
  docker tag springcommunity/spring-petclinic-${svc}:latest \
    ${ECR}/petclinic/spring-petclinic-${svc}:v1.0
  docker push ${ECR}/petclinic/spring-petclinic-${svc}:v1.0
done
```

### Day 3 — Helm Chart

The Helm chart is in `helm/petclinic/`. It creates:
- 6 Deployments (1 per microservice) with init-container startup ordering
- 6 ClusterIP Services
- 1 ALB Ingress (routes `/` → api-gateway)
- 4 HorizontalPodAutoscalers (api-gateway, customers, vets, visits)
- 1 ConfigMap (Spring profiles, Eureka URL, datasource URL)

### Day 4 — Deploy to EKS

```bash
# Deploy MySQL
kubectl apply -f k8s/mysql/mysql-secret.yaml
kubectl apply -f k8s/mysql/mysql.yaml
kubectl -n petclinic rollout status deployment/mysql

# Deploy all services
helm install petclinic ./helm/petclinic \
  --namespace petclinic \
  --create-namespace \
  --wait --timeout 10m

# Get the ALB DNS name
kubectl -n petclinic get ingress petclinic-ingress
```

### Day 5 — CI/CD + Monitoring

```bash
# Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=petclinic123

# Access Grafana (localhost:3000, admin/petclinic123)
kubectl -n monitoring port-forward \
  $(kubectl -n monitoring get pod -l app.kubernetes.io/name=grafana -oname) 3000
```

GitHub Actions CI/CD: add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as repository secrets. Every push to `main` builds, pushes, and deploys automatically.

### Day 6 — Security & Hardening

```bash
# Apply NetworkPolicy (default-deny + explicit allow rules)
kubectl apply -f k8s/network-policy.yaml

# Apply ResourceQuota
kubectl apply -f k8s/resource-quota.yaml

# Run chaos demo
./scripts/chaos-demo.sh api-gateway
```

---

## Cost Management

```bash
# Stop EC2 billing (preserves data)
./scripts/destroy-nodes.sh

# Restore cluster
./scripts/restore-nodes.sh
```

> **Note:** EBS volumes and ALB continue to incur small charges even when nodes are stopped.

---

## Repository Structure

```
.
├── .github/workflows/deploy.yml   # GitHub Actions CI/CD pipeline
├── helm/petclinic/                # Helm chart for all 6 services
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml        # Init-container startup ordering
│       ├── service.yaml
│       ├── ingress.yaml           # ALB ingress
│       ├── hpa.yaml               # Horizontal Pod Autoscaler
│       └── configmap.yaml
├── k8s/
│   ├── mysql/                     # MySQL deployment + PVC + secret
│   ├── network-policy.yaml        # Pod-to-pod traffic restrictions
│   └── resource-quota.yaml        # Namespace resource limits
├── scripts/
│   ├── chaos-demo.sh              # Kill a pod, watch self-healing
│   ├── destroy-nodes.sh           # Scale nodes to 0 (save cost)
│   └── restore-nodes.sh           # Scale nodes back to 2
├── terraform/                     # EKS, VPC, ECR, IAM via Terraform
│   ├── backend.tf
│   ├── vpc.tf
│   ├── eks.tf
│   ├── ecr.tf
│   ├── iam.tf
│   ├── variables.tf
│   └── outputs.tf
└── docs/
    └── architecture.md
```

---

## Key Learnings

- **EKS 1.23+ requires EBS CSI Driver** — the in-tree `kubernetes.io/aws-ebs` provisioner is removed; install `aws-ebs-csi-driver` addon before creating PVCs
- **Init containers enforce startup order** — TCP port checks (`nc -z`) are more reliable than HTTP health checks for cross-service readiness
- **IRSA for ALB Controller** — IAM Roles for Service Accounts eliminates hardcoded credentials and 12-hour token expiry
- **Node IAM role for ECR** — attaching `AmazonEC2ContainerRegistryReadOnly` to the node role removes the need for imagePullSecrets
- **Docker Buildx on GitHub Actions** — avoid `docker/setup-buildx-action` when using `--load`; it creates a `docker-container` driver that doesn't support manifest-list exports

---

## Original Project

This deployment is based on the official [spring-petclinic/spring-petclinic-microservices](https://github.com/spring-petclinic/spring-petclinic-microservices) repository.
