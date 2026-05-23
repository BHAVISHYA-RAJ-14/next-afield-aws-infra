# ElastiCache Module

This module provisions an AWS ElastiCache Redis cluster.

## Features
- Redis 7.1 deployment.
- Single node setup (cost-optimized for dev).
- Private subnet placement.
- Security group restricted to VPC CIDR.

## Usage
```hcl
module "elasticache" {
  source          = "../elasticache"
  environment     = "dev"
  vpc_id          = "vpc-123"
  vpc_cidr        = "10.0.0.0/16"
  private_subnets = ["subnet-1", "subnet-2"]
}
```

## Inputs
| Name | Description | Type | Default |
|------|-------------|------|---------|
| environment | Environment name | string | n/a |
| vpc_id | VPC ID | string | n/a |
| vpc_cidr | VPC CIDR block | string | n/a |
| private_subnets | Subnets for Redis | list(string) | n/a |

## Outputs
| Name | Description |
|------|-------------|
| cache_nodes | Redis node endpoints |
| cluster_id | Redis cluster ID |
