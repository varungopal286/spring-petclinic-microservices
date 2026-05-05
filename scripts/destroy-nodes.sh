#!/bin/bash
# Scale down EKS nodes to 0 to stop EC2 billing when cluster is not in use.
# MySQL data is preserved on the EBS PVC; it will reattach on restore.

CLUSTER=petclinic-cluster
NODEGROUP=petclinic-20260505093018317600000001
REGION=ap-south-1

echo "Scaling node group to 0..."
aws eks update-nodegroup-config \
  --cluster-name $CLUSTER \
  --nodegroup-name $NODEGROUP \
  --scaling-config minSize=0,maxSize=3,desiredSize=0 \
  --region $REGION

echo "Waiting for scale-down to complete (this takes 3-5 minutes)..."
aws eks wait nodegroup-active \
  --cluster-name $CLUSTER \
  --nodegroup-name $NODEGROUP \
  --region $REGION

echo "Done. EC2 instances stopped. EBS volumes and ALB still incur minor charges."
echo "Run ./scripts/restore-nodes.sh to bring the cluster back up."
