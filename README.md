# terraform-eks-karpenter-multarch

Automate AWS EKS cluster setup with Karpenter, while utilizing Graviton and Spot instances.

This repository contains Terraform code to create an Amazon EKS cluster in a dedicated VPC and install Karpenter. The setup supports provisioning both x86_64 and arm64 (Graviton) Spot instances.

---

## What this repo does

- Creates a VPC across 3 Availability Zones (AZs)
- Deploys an EKS control plane using [`terraform-aws-modules/eks/aws`](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- Installs Karpenter via the Helm provider
- Creates two sample Karpenter Provisioners:
  - One favoring **x86** nodes
  - One favoring **arm64/Graviton** nodes

> **Note:** Set `var.kubernetes_version` to the latest EKS-supported Kubernetes version before applying. See [AWS EKS docs](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html).

---

## Files

- `providers.tf` - Terraform providers configuration  
- `vpc.tf` - VPC and subnets  
- `eks.tf` - EKS cluster configuration  
- `karpenter.tf` - IAM roles, Helm release for Karpenter, and sample provisioners  
- `variables.tf` - Input variables for cluster customization  
- `test.yaml` - Example deployment demonstrating scheduling pods on x86 or Graviton nodes  

---

## Quick Usage

1. Install Terraform >= 1.5 and AWS CLI  
2. Configure AWS credentials (environment variables or shared credentials file)  
3. Edit `variables.tf` to set:
   - `cluster_name`
   - `region`
   - `kubernetes_version`
4. Initialize Terraform:
   ```bash
   terraform init
5. Apply the Configuration:
   ```bash
  terraform apply

6.  Scheduling Pods on x86 vs Graviton

Provisioners in karpenter.tf apply taints and node labels:

kubernetes.io/arch=amd64 → x86 nodes

kubernetes.io/arch=arm64 → Graviton nodes

Developers can set nodeSelector in pod specs to target a specific architecture:

apiVersion: v1
kind: Pod
metadata:
  name: sample-x86
spec:
  containers:
    - name: nginx
      image: nginx
  nodeSelector:
    kubernetes.io/arch: amd64

apiVersion: v1
kind: Pod
metadata:
  name: sample-arm64
spec:
  containers:
    - name: nginx
      image: nginx
  nodeSelector:
    kubernetes.io/arch: arm64

General Architecture
flowchart LR
    subgraph AWS_Cloud["AWS Cloud"]
        ALB[Application Load Balancer]
        EKS[EKS Cluster\nx86 + ARM nodes]
        RDS[(PostgreSQL RDS)]
    end

    subgraph CI_CD["CI/CD"]
        GitHub[GitHub Actions / GitLab CI]
        Registry[ECR / Artifact Registry]
    end

    User -->|HTTPS| ALB
    ALB -->|Service Traffic| EKS
    EKS -->|DB Traffic| RDS
    GitHub --> Registry --> EKS

1. Cloud Environment Structure

AWS Accounts Recommended:

Master/Management Account: Billing, IAM, centralized logging

Development Account: Sandbox for dev/test

Staging Account: Pre-production QA/testing

Production Account: Live environment, fully isolated

2. Network Design

VPC with multiple subnets:

Public Subnets: For ALB/NLB

Private Subnets: For application nodes and databases

Isolated Subnets: For sensitive workloads or backups

Security:

Security Groups for pods/services

Network ACLs for extra protection

Private endpoints for RDS and EKS

3. Node Groups & Scaling

Mixed architecture nodes (x86 + ARM/Graviton) for cost optimization

On-demand nodes for critical workloads

Spot nodes for cost-efficient workloads

Karpenter for dynamic provisioning

4. Containerization & CI/CD

Images: Docker images for backend (Flask) and frontend (React)

Registry: AWS ECR

Deployment: GitHub Actions or similar CI/CD pipelines

5. Database (PostgreSQL)

High Availability: Multi-AZ deployments

Backups: Automated daily snapshots

Disaster Recovery: Optional cross-region read replicas

Optional Enhancements

Enable Prometheus/Grafana for metrics

Use AWS Systems Manager Parameter Store or Secrets Manager for secrets

Add a Web Application Firewall (WAF) in front of the ALB for security
