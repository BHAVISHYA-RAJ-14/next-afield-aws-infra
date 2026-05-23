# RDS Module

This module provisions an AWS RDS PostgreSQL instance.

## Features
- PostgreSQL 16.1 deployment.
- Private subnet placement.
- Security group restricted to VPC CIDR.
- Configurable master password via variables.

## Usage
```hcl
module "rds" {
  source          = "../rds"
  environment     = "dev"
  vpc_id          = "vpc-123"
  vpc_cidr        = "10.0.0.0/16"
  private_subnets = ["subnet-1", "subnet-2"]
  db_password     = "YourSecurePassword"
}
```

## Inputs
| Name | Description | Type | Default |
|------|-------------|------|---------|
| environment | Environment name | string | n/a |
| vpc_id | VPC ID | string | n/a |
| vpc_cidr | VPC CIDR block | string | n/a |
| private_subnets | Subnets for DB | list(string) | n/a |
| db_password | Master password | string | n/a |

## Outputs
| Name | Description |
|------|-------------|
| db_instance_endpoint | The connection endpoint |
| db_instance_identifier | The RDS identifier |
