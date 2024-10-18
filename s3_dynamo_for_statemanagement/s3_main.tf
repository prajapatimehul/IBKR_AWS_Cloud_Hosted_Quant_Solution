provider "aws" {
  region  = var.aws_region
  profile = "terraform"
}

# Generate a random suffix to ensure uniqueness for the bucket and DynamoDB table
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Create an S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "quant-terraform-state-bucket-${random_id.bucket_suffix.hex}"

  versioning {
    enabled = true
  }

  tags = {
    Name        = "TerraformState"
    
  }
}

# Create a DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks-${random_id.bucket_suffix.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "TerraformLocks"
  
  }
}

# Output the bucket name and DynamoDB table name for use in other configurations
output "bucket_name" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "The S3 bucket name for storing Terraform state files"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "The DynamoDB table name for Terraform state locking"
}