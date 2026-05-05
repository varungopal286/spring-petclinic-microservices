#!/bin/bash
# Scale EKS nodes back to 2. Pods reschedule automatically.
# MySQL reattaches to its EBS PVC; app is ready in ~5 minutes.

CLUSTER=petclinic-cluster
NODEGROUP=petclinic-20260505093018317600000001
REGION=ap-south-1

echo "Scaling node group back to 2..."
aws eks update-nodegroup-config \
  --cluster-name $CLUSTER \
  --nodegroup-name $NODEGROUP \
  --scaling-config minSize=2,maxSize=3,desiredSize=2 \
  --region $REGION

echo "Waiting for nodes to be ready (this takes 3-5 minutes)..."
aws eks wait nodegroup-active \
  --cluster-name $CLUSTER \
  --nodegroup-name $NODEGROUP \
  --region $REGION

echo "Nodes ready. Pods will reschedule automatically."
echo "Check status with: kubectl -n petclinic get pods -w"
