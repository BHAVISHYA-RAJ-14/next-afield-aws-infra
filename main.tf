terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "next-afield-tf-state-bhavishya"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "next-afield-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# ==========================================
# 1. Network Foundation (VPC Module)
# ==========================================
module "vpc" {
  source = "./modules/vpc"

  vpc_name    = "next-afield-vpc"
  environment = "dev"
  cidr_block  = "10.0.0.0/16"
  
  # Deploying across two Availability Zones for high availability
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # COST SAVING: Disabled for lab environment to avoid $32/month charge
  enable_nat_gateway = false
  single_nat_gateway = false
}

# ==========================================
# 2. Compute Infrastructure (EKS Module)
# ==========================================
module "eks" {
  source = "./modules/eks"

  cluster_name    = "next-afield-cluster"
  cluster_version = "1.29"
  environment     = "dev"

  # Dynamically fetching network data directly from the VPC module above
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
}

# ==========================================
# 3. Database Layer (RDS Module)
# ==========================================
module "rds" {
  source = "./modules/rds"

  environment     = "dev"
  
  # Dynamically fetching network data from the VPC module
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = "10.0.0.0/16" 
  private_subnets = module.vpc.private_subnets
  
  # Note: In a production environment, this would be fetched from AWS Secrets Manager.
  # For this lab, we are passing it directly.
  db_password     = "SuperSecretPassword123!" 
}

# ==========================================
# 4. Caching Layer (ElastiCache Module)
# ==========================================
module "elasticache" {
  source = "./modules/elasticache"

  environment     = "dev"
  
  # Dynamically fetching network data from the VPC module
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = "10.0.0.0/16"
  private_subnets = module.vpc.private_subnets
}