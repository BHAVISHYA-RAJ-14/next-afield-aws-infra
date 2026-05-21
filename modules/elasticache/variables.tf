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
  description = "List of private subnet IDs for the cache"
  type        = list(string)
}
