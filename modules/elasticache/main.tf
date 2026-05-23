# 1. Subnet Group for Redis
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnets
}

# 2. Security Group (Allowing traffic only from within the VPC)
resource "aws_security_group" "redis" {
  name_prefix = "${var.environment}-redis-sg-"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow Redis traffic from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Environment = var.environment
  }
}

# 3. ElastiCache Redis Cluster (Free Tier Configured)
resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.environment}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  tags = {
    Environment = var.environment
  }
}