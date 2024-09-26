# Data source to find the existing volume
data "aws_ebs_volume" "existing_docker_data" {
  count = 0  # Set to 0 initially
  most_recent = true

  filter {
    name   = "volume-type"
    values = ["gp3"]
  }

  filter {
    name   = "tag:Name"
    values = ["DockerDataVolume"]
  }

  filter {
    name   = "availability-zone"
    values = [aws_subnet.main[0].availability_zone]
  }
}

# EBS volume resource
resource "aws_ebs_volume" "docker_data" {
  count             = length(data.aws_ebs_volume.existing_docker_data) == 0 ? 1 : 0
  availability_zone = aws_subnet.main[0].availability_zone
  size              = 10  # Default size, adjust as needed
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "DockerDataVolume"
  }
}

# Volume attachment
resource "aws_volume_attachment" "docker_data_att" {
  device_name = "/dev/xvdf"
  volume_id   = length(data.aws_ebs_volume.existing_docker_data) > 0 ? data.aws_ebs_volume.existing_docker_data[0].id : aws_ebs_volume.docker_data[0].id
  instance_id = aws_instance.docker.id
}

# Outputs
output "ebs_volume_id" {
  value = length(data.aws_ebs_volume.existing_docker_data) > 0 ? data.aws_ebs_volume.existing_docker_data[0].id : (length(aws_ebs_volume.docker_data) > 0 ? aws_ebs_volume.docker_data[0].id : null)
  description = "ID of the EBS volume for Docker data"
}

output "ebs_volume_arn" {
  value = length(data.aws_ebs_volume.existing_docker_data) > 0 ? data.aws_ebs_volume.existing_docker_data[0].arn : (length(aws_ebs_volume.docker_data) > 0 ? aws_ebs_volume.docker_data[0].arn : null)
  description = "ARN of the EBS volume for Docker data"
}