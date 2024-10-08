variable "aws_region" {
  description = "The AWS region to deploy resources in"
  default     = "us-east-1"
}

variable "my_ip" {
  description = "The IP address or range to allow SSH and HTTPS access from"
  type        = string
  default     = "0.0.0.0/0"  # Default to open (this can be changed to any dummy IP)
}

variable "key_name" {
  description = "The name of the SSH key pair"
  default     = "deploy-key_IB_gateway"
}

variable "public_key_path" {
  description = "The path to the public key to use f or SSH access"
  default     = "~/.ssh/deploy-key.pub"
}

variable "instance_type" {
  description = "The EC2 instance type"
  default     = "t3.small"
}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance"
  default     = "ami-0e1fd4ed3e0403447"  # ubuntu image
}

variable "your_home_ip" {
  description = "IP address for security"
  default     = "0.0.0.0"  # ubuntu image
}