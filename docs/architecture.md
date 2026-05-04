# Spring PetClinic Microservices — Architecture

## Overview
Cloud-native veterinary clinic management deployed on AWS EKS
using a microservices architecture with full CI/CD and observability.

## Microservices
| Service           | Port | Responsibility                        |
|-------------------|------|---------------------------------------|
| config-server     | 8888 | Central config store for all services |
| discovery-server  | 8761 | Eureka service registry               |
| api-gateway       | 8080 | Single entry point, routing           |
| customers-service | 8081 | Owner and pet management              |
| vets-service      | 8083 | Veterinarian data                     |
| visits-service    | 8082 | Visit scheduling                      |

## Startup Order
config-server → discovery-server → [customers, vets, visits, api-gateway]
(Enforced via Kubernetes init containers in Helm chart)

## Infrastructure Stack
| Layer         | Technology                    |
|---------------|-------------------------------|
| Cloud         | AWS (ap-south-1 / Mumbai)     |
| IaC           | Terraform                     |
| Networking    | AWS VPC (public subnets)      |
| Orchestration | AWS EKS (Kubernetes 1.29)     |
| Registry      | AWS ECR                       |
| Ingress       | AWS Application Load Balancer |
| CI/CD         | GitHub Actions                |
| Packages      | Helm                          |
| Monitoring    | Prometheus + Grafana          |
| Tracing       | Zipkin                        |
