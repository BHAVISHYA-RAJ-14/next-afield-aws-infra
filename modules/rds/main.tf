# 1. Subnet Group for RDS (Placing it in the private subnets)
resource "aws_db_subnet_group" "this" {
  name       = "${var.environment}-rds-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Environment = var.environment
  }
}

# 2. Security Group (Allowing traffic only from within the VPC)
resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-rds-sg-"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow PostgreSQL traffic from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Environment = var.environment
  }
}

# 3. PostgreSQL Database Instance (Free Tier Configured)
resource "aws_db_instance" "this" {
  identifier             = "${var.environment}-postgres"
  engine                 = "postgres"
  engine_version         = "16.1"
  
  # FREE TIER ELIGIBLE SETTINGS
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  # CRITICAL FOR LABS: Allows terraform destroy without hanging
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Environment = var.environment
  }
}