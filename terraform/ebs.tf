# Data source to find the existing volume
data "aws_ebs_volume" "existing_docker_data" {
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
  availability_zone = data.aws_ebs_volume.existing_docker_data.availability_zone
  size              = data.aws_ebs_volume.existing_docker_data.size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "DockerDataVolume"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [size, type, encrypted, tags]
  }
}

# Volume attachment
resource "aws_volume_attachment" "docker_data_att" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.docker_data.id
  instance_id = aws_instance.docker.id
}