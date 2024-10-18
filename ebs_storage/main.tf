provider "aws" {
  region  = var.aws_region
  profile = "quant"
}



# Configure backend to use the dynamically fetched bucket and DynamoDB table
terraform {
  backend "s3" {
    bucket         = data.aws_s3_bucket.terraform_state.id  # Dynamically get the bucket name
    key            = "ebs/terraform.tfstate"  # Path in the bucket for the EBS state file
    region         = var.aws_region
    dynamodb_table = data.aws_dynamodb_table.terraform_locks.name  # Dynamically get the DynamoDB table name
    encrypt        = true
  }
}
# EBS volume resource
resource "aws_ebs_volume" "docker_data" {
  availability_zone = var.availability_zone
  size              = 10  # Adjust as needed
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "DockerDataVolume"
  }
}

# Outputs to expose the EBS volume ID (optional)
output "ebs_volume_id" {
  value = aws_ebs_volume.docker_data.id
}