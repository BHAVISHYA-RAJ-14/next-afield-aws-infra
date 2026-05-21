module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Allow your local machine to run kubectl commands against the cluster
  cluster_endpoint_public_access = true

  # Network Configuration (Passed from our VPC module)
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  # Enable OIDC Provider for IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Required EKS Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Managed Node Groups (Compute Capacity)
  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    # Spot instance node group to save on AWS costs
    spot_nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.small"]
      capacity_type  = "SPOT"

      tags = {
        Environment = var.environment
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }
    }
  }

  tags = {
    Environment = var.environment
  }
}