#!/bin/bash
# Chaos Engineering Demo — kill a pod and watch Kubernetes self-heal.
# Usage:  ./scripts/chaos-demo.sh [service-name]
# Default target: api-gateway

NAMESPACE=petclinic
TARGET=${1:-api-gateway}

echo "========================================"
echo " Chaos Demo — target: $TARGET"
echo "========================================"
echo ""

# Show current pod state
echo "[1] Current pods:"
kubectl -n $NAMESPACE get pods -l app=$TARGET
echo ""

# Identify the pod to kill
POD=$(kubectl -n $NAMESPACE get pod -l app=$TARGET -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD" ]; then
  echo "ERROR: No pod found for app=$TARGET in namespace $NAMESPACE"
  exit 1
fi

echo "[2] Deleting pod: $POD"
kubectl -n $NAMESPACE delete pod $POD
echo ""

echo "[3] Watching recovery (Ctrl+C to stop)..."
echo "    Kubernetes will schedule a replacement pod immediately."
echo ""
kubectl -n $NAMESPACE get pods -l app=$TARGET -w
