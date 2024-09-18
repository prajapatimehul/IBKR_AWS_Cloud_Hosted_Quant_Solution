#!/bin/bash

# Update the system
set -euxo pipefail

export HOME=/home/ubuntu

# Use a different mirror
sudo sed -i 's/us-east-1.ec2.archive.ubuntu.com/archive.ubuntu.com/g' /etc/apt/sources.list

# Increase retry attempts
echo 'Acquire::Retries "3";' | sudo tee /etc/apt/apt.conf.d/80-retries

# Update and clean package lists
sudo apt-get clean
sudo apt-get update -y

# Install Docker
sudo apt-get install -y docker.io

# Install newest version of docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Docker Compose with --fix-missing flag
#sudo apt-get install -y --fix-missing docker-compose

# ... rest of your script ...

sudo systemctl start docker
sudo usermod -aG docker ubuntu

# Install AWS CLI
sudo apt-get install -y awscli

# Install Git
sudo apt-get install git -y

sudo apt-get install -y tigervnc-viewer

# Add the CloudWatch Agent repository
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

# Install the CloudWatch Agent
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

# Clean up the downloaded package
rm amazon-cloudwatch-agent.deb

# Create CloudWatch Agent configuration file in JSON format
cat <<EOT | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "IB-Gateway-Docker",
            "log_stream_name": "{instance_id}-messages",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/cloud-init.log",
            "log_group_name": "IB-Gateway-Docker",
            "log_stream_name": "{instance_id}-cloud-init",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "IB-Gateway-Docker",
            "log_stream_name": "{instance_id}-cloud-init-output",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/docker.log",
            "log_group_name": "IB-Gateway-Docker",
            "log_stream_name": "{instance_id}-docker",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOT

# Restart CloudWatch Agent to apply new configuration
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Clone the IB Gateway Docker repository
#git clone https://github.com/UnusualAlpha/ib-gateway-docker.git /home/ubuntu/ib-gateway-docker
git clone https://github.com/gnzsnz/ib-gateway-docker.git /home/ubuntu/ib-gateway-docker
# Create a script to fetch parameters from AWS Parameter Store and create .env file
cat << 'EOF' > /home/ubuntu/create_env_file.sh
#!/bin/bash

# Set your AWS region
AWS_REGION="us-east-1"

# File to write the environment variables
ENV_FILE="/home/ubuntu/ib-gateway-docker/.env"

# Clear the existing .env file or create a new one
> $ENV_FILE

# Fetch parameters from Parameter Store and write to .env file
echo "TWS_USERID=$(aws ssm get-parameter --name /IB_Gateway/TWS_USERID --with-decryption --query Parameter.Value --output text --region $AWS_REGION)" >> $ENV_FILE
echo "TWS_PASSWORD=$(aws ssm get-parameter --name /IB_Gateway/TWS_PASSWORD --with-decryption --query Parameter.Value --output text --region $AWS_REGION)" >> $ENV_FILE
echo "TWS_USERID_PAPER=$(aws ssm get-parameter --name /IB_Gateway/TWS_USERID_PAPER --with-decryption --query Parameter.Value --output text --region $AWS_REGION)" >> $ENV_FILE
echo "TWS_PASSWORD_PAPER=$(aws ssm get-parameter --name /IB_Gateway/TWS_PASSWORD_PAPER --with-decryption --query Parameter.Value --output text --region $AWS_REGION)" >> $ENV_FILE
echo "VNC_SERVER_PASSWORD=$(aws ssm get-parameter --name /IB_Gateway/VNC_SERVER_PASSWORD --with-decryption --query Parameter.Value --output text --region $AWS_REGION)" >> $ENV_FILE

echo ".env file created successfully"
EOF

# Make the script executable
chmod +x /home/ubuntu/create_env_file.sh

# Run the script to create .env file
/home/ubuntu/create_env_file.sh

# Run docker-compose
cd /home/ubuntu/ib-gateway-docker


#sudo sed -i '/^name: algo-trader$/d' docker-compose.yml


docker-compose up -d > compose_output.log 2>&1

# Message indicating that setup is complete
echo "Docker, Git, and CloudWatch Agent installed, repository cloned. Docker container should be running."
echo "To connect to the VNC server, SSH into the instance and run:"
echo "vncviewer localhost:5900"
echo "You may need to use SSH tunneling to securely connect to the VNC server."