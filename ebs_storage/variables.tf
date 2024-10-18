variable "aws_region" {
  description = "The AWS region to deploy resources in"
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "The AWS Availability Zone where the EBS volume will be created"
  type        = string
  default     = "us-east-1a"  # Set the appropriate default AZ
}