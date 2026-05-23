# VPC Module

This module provisions the networking foundation for the project.

## Features
- Multi-AZ VPC deployment (default 2 AZs).
- Public and Private subnets.
- Tagging for EKS Load Balancer discovery.
- Configurable NAT Gateway (disabled by default for cost saving).

## Usage
```hcl
module "vpc" {
  source      = "../vpc"
  vpc_name    = "my-vpc"
  environment = "dev"
  cidr_block  = "10.0.0.0/16"
  azs         = ["us-east-1a", "us-east-1b"]
}
```

## Inputs
| Name | Description | Type | Default |
|------|-------------|------|---------|
| vpc_name | Name of the VPC | string | n/a |
| environment | Environment name (dev/prod) | string | n/a |
| cidr_block | CIDR block for the VPC | string | "10.0.0.0/16" |
| azs | List of availability zones | list(string) | n/a |
| private_subnets | List of private subnet CIDRs | list(string) | n/a |
| public_subnets | List of public subnet CIDRs | list(string) | n/a |
| enable_nat_gateway | Enable NAT Gateway | bool | false |

## Outputs
| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| private_subnets | IDs of private subnets |
| public_subnets | IDs of public subnets |
