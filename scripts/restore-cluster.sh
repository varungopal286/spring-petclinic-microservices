#!/bin/bash
# Full cluster restore — run this once before your presentation.
# Takes ~40 minutes from zero to live app.
# Prerequisites: AWS CLI configured, terraform, kubectl, helm installed.

set -e

REGION=ap-south-1
CLUSTER=petclinic-cluster
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=================================================="
echo " PetClinic on EKS — Full Restore"
echo " Working directory: $SCRIPT_DIR"
echo "=================================================="
echo ""

cd "$SCRIPT_DIR"

# ── Step 1: Terraform ──────────────────────────────────
echo "[1/8] Provisioning AWS infrastructure with Terraform..."
cd terraform
terraform init -reconfigure
terraform apply
cd "$SCRIPT_DIR"
echo ""

# ── Step 2: Configure kubectl ──────────────────────────
echo "[2/8] Configuring kubectl..."
aws eks update-kubeconfig --name $CLUSTER --region $REGION
echo ""

# ── Step 3: Metrics server ─────────────────────────────
echo "[3/8] Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
echo ""

# ── Step 4: ALB controller ─────────────────────────────
echo "[4/8] Installing AWS Load Balancer Controller..."
ALB_ROLE_ARN=$(cd terraform && terraform output -raw alb_controller_role_arn)
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update eks
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=$CLUSTER \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$ALB_ROLE_ARN" \
  --wait
echo ""

# ── Step 5: MySQL ──────────────────────────────────────
echo "[5/8] Deploying MySQL..."
kubectl create namespace petclinic --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/mysql/mysql-secret.yaml
kubectl apply -f k8s/mysql/mysql.yaml
kubectl -n petclinic rollout status deployment/mysql --timeout=5m
echo ""

# ── Step 6: PetClinic app ──────────────────────────────
echo "[6/8] Deploying PetClinic via Helm..."
helm upgrade --install petclinic ./helm/petclinic \
  --namespace petclinic \
  --create-namespace \
  --wait \
  --timeout 10m
echo ""

# ── Step 7: Security policies ──────────────────────────
echo "[7/8] Applying NetworkPolicy and ResourceQuota..."
kubectl apply -f k8s/network-policy.yaml
kubectl apply -f k8s/resource-quota.yaml
echo ""

# ── Step 8: Monitoring ─────────────────────────────────
echo "[8/8] Installing Prometheus + Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=petclinic123 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --timeout 5m
echo ""

# ── Done ───────────────────────────────────────────────
echo "=================================================="
echo " Restore complete!"
echo "=================================================="
echo ""
echo "App URL (wait 2-3 min for ALB to provision):"
kubectl -n petclinic get ingress petclinic-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null && echo "" || \
  echo "  Run: kubectl -n petclinic get ingress petclinic-ingress"
echo ""
echo "Grafana:  kubectl -n monitoring port-forward \$(kubectl -n monitoring get pod -l app.kubernetes.io/name=grafana -oname) 3000"
echo "          http://localhost:3000  admin / petclinic123"
