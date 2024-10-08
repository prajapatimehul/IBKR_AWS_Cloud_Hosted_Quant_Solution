provider "aws" {
  region  = var.aws_region
  profile = "terraform"
}

# Create a new VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "IB-Gateway-VPC"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "IB-Gateway-IGW"
  }
}

# Create a subnet
resource "aws_subnet" "main" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = "us-east-1${["a", "b", "c"][count.index]}"

  tags = {
    Name = "IB-Gateway-Subnet-${count.index + 1}"
  }
}

# Create a route table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "IB-Gateway-RouteTable"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "main" {
  count          = 3
  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main.id
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "docker_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "docker-sg"
  description = "Allow SSH and HTTPS inbound traffic from specified IP address or range"

  # Allow SSH (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Allow HTTPS (port 443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    from_port   = 5900
    to_port     = 5900
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
resource "aws_iam_role" "ssm_role_IB" {
  name = "ssm_role_IB"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_policy" {
  name   = "ssm_policy"
  role   = aws_iam_role.ssm_role_IB.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource",
          "ssm:CreateAssociation",
          "ssm:DeleteAssociation",
          "ssm:DescribeDocument",
          "ssm:DescribeAssociation",
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:GetDocument",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:SendReply",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm_instance_profile_IB"
  role = aws_iam_role.ssm_role_IB.name
}

resource "aws_instance" "docker" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.docker_sg.id]
  subnet_id              = aws_subnet.main[0].id  # Use the first subnet
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name
  
  user_data = file("${path.module}/user_data_ib-gateway-docker.sh")
  tags = {
    Name = "DockerInstance"
  }
}

# resource "aws_volume_attachment" "docker_data_att" {
#   device_name = "/dev/xvdf"
#   volume_id   = aws_ebs_volume.docker_data.id
#   instance_id = aws_instance.docker.id
# }

# Allocate a new Elastic IP
resource "aws_eip" "docker_eip" {
  domain      = "vpc"
  instance = aws_instance.docker.id

  tags = {
    Name = "IB-Gateway-EIP"
  }
}

output "eip_public_ip" {
  value = aws_eip.docker_eip.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/deploy-key ubuntu@${aws_eip.docker_eip.public_ip}"
}