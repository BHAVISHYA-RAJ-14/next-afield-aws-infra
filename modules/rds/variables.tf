variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC to allow internal traffic"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs for the database"
  type        = list(string)
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "nextafielddb"
}

variable "db_username" {
  description = "Master username"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}