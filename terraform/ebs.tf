# Data source to find the existing volume
data "aws_ebs_volume" "existing_docker_data" {
  count = 1
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
  size              = 50  # Default size, adjust as needed
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