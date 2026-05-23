# EKS Module

This module provisions an AWS EKS Cluster with a Managed Node Group.

## Features
- EKS Cluster (Control Plane).
- Managed Node Group with Spot instances for cost saving.
- IRSA (IAM Roles for Service Accounts) enabled.
- VPC CNI, CoreDNS, and Kube-Proxy addons.

## Usage
```hcl
module "eks" {
  source          = "../eks"
  cluster_name    = "my-cluster"
  cluster_version = "1.29"
  vpc_id          = "vpc-123"
  private_subnets = ["subnet-1", "subnet-2"]
}
```

## Inputs
| Name | Description | Type | Default |
|------|-------------|------|---------|
| cluster_name | Name of the EKS cluster | string | n/a |
| cluster_version | K8s version | string | "1.29" |
| environment | Environment name | string | n/a |
| vpc_id | VPC ID to deploy into | string | n/a |
| private_subnets | Subnets for node group | list(string) | n/a |

## Outputs
| Name | Description |
|------|-------------|
| cluster_name | EKS Cluster Name |
| cluster_endpoint | EKS API Endpoint |
| cluster_security_group_id | Security group ID of the cluster |
