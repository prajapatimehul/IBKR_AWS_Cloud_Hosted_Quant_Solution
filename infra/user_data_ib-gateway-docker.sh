#!/bin/bash


# Enable error logging
exec 1> >(tee -a "/var/log/cloud-init-script.log")
exec 2> >(tee -a "/var/log/cloud-init-script.log" >&2)

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Trap errors
trap 'log "Error on line $LINENO"' ERR

# Start script
log "Starting script execution"

# Update the system
set -euxo pipefail

# Create error handling function
handle_error() {
    log "Error on line $LINENO: Exit code $?"
}
trap 'handle_error' ERR

export HOME=/home/ubuntu

# Use a different mirror
sudo sed -i 's/us-east-1.ec2.archive.ubuntu.com/archive.ubuntu.com/g' /etc/apt/sources.list

# Increase retry attempts
echo 'Acquire::Retries "3";' | sudo tee /etc/apt/apt.conf.d/80-retries

if ! sudo apt-get update -y; then
    log "ERROR: apt-get update failed"
    exit 1
fi


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

if ! sudo systemctl start docker; then
    log "ERROR: Failed to start Docker"
    # Try to get Docker status
    sudo systemctl status docker
    exit 1
fi

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

# Change to the directory where you want to store your project
cd /home/ubuntu

if ! git clone https://github.com/Jamesd000/IBKR_AWS_Cloud_Hosted_Quant_Solution.git; then
    log "ERROR: Git clone failed"
    # Check git version and connectivity
    git --version
    ping -c 1 github.com
    exit 1
fi

# Clone the repository (you'll need access to the repository, if it's private)
#git clone https://github.com/Jamesd000/IBKR_AWS_Cloud_Hosted_Quant_Solution.git


# Move to the desired folder and copy it to the desired location
cd /home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution
#cp -r ib-gateway-docker /home/ubuntu/ib-gateway-docker
git checkout v1.1

# Clean up the rest of the repository if you don't need it
#rm -rf /home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution

# Additional steps if needed for Docker setup or configuration
#cd /home/ubuntu/ib-gateway-docker

# Create a script to fetch parameters from AWS Parameter Store and create .env file
cat << 'EOF' > /home/ubuntu/create_env_file.sh
#!/bin/bash

# Set your AWS region
AWS_REGION="us-east-1"

# File to write the environment variables
#ENV_FILE="/home/ubuntu/ib-gateway-docker/.env"
ENV_FILE="/home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution/.env"

# Clear the existing .env file or create a new one
> $ENV_FILE

# Function to fetch parameter and write to .env file
fetch_and_write_param() {
    local param_name=$1
    local env_var_name=$2
    value=$(aws ssm get-parameter --name "$param_name" --with-decryption --query Parameter.Value --output text --region $AWS_REGION 2>/dev/null)
    if [ $? -eq 0 ] && [ ! -z "$value" ]; then
        # Ensure value is properly sanitized and there's no extra newline
        value=$(echo "$value" | tr -d '\n' | tr -d '\r')
        echo "${env_var_name}=${value}" >> $ENV_FILE
    fi
}

# Main parameters
fetch_and_write_param "/IB_Gateway/TWS_USERID" "TWS_USERID"
fetch_and_write_param "/IB_Gateway/TWS_PASSWORD" "TWS_PASSWORD"
fetch_and_write_param "/IB_Gateway/TRADING_MODE" "TRADING_MODE"
fetch_and_write_param "/IB_Gateway/VNC_SERVER_PASSWORD" "VNC_SERVER_PASSWORD"
fetch_and_write_param "/IB_Gateway/JUPYTER_TOKEN" "JUPYTER_TOKEN"
fetch_and_write_param "/IB_Gateway/TWS_USERID" "TWS_USERID_PAPER"
fetch_and_write_param "/IB_Gateway/TWS_PASSWORD" "TWS_PASSWORD_PAPER"

# Advanced parameters
fetch_and_write_param "/IB_Gateway/TWS_SETTINGS_PATH" "TWS_SETTINGS_PATH"
fetch_and_write_param "/IB_Gateway/TWS_ACCEPT_INCOMING" "TWS_ACCEPT_INCOMING"
fetch_and_write_param "/IB_Gateway/READ_ONLY_API" "READ_ONLY_API"
fetch_and_write_param "/IB_Gateway/TWOFA_TIMEOUT_ACTION" "TWOFA_TIMEOUT_ACTION"
fetch_and_write_param "/IB_Gateway/BYPASS_WARNING" "BYPASS_WARNING"
fetch_and_write_param "/IB_Gateway/AUTO_RESTART_TIME" "AUTO_RESTART_TIME"
fetch_and_write_param "/IB_Gateway/AUTO_LOGOFF_TIME" "AUTO_LOGOFF_TIME"
fetch_and_write_param "/IB_Gateway/TWS_COLD_RESTART" "TWS_COLD_RESTART"
fetch_and_write_param "/IB_Gateway/SAVE_TWS_SETTINGS" "SAVE_TWS_SETTINGS"
fetch_and_write_param "/IB_Gateway/RELOGIN_AFTER_TWOFA_TIMEOUT" "RELOGIN_AFTER_TWOFA_TIMEOUT"
fetch_and_write_param "/IB_Gateway/TWOFA_EXIT_INTERVAL" "TWOFA_EXIT_INTERVAL"
fetch_and_write_param "/IB_Gateway/TWOFA_DEVICE" "TWOFA_DEVICE"
fetch_and_write_param "/IB_Gateway/EXISTING_SESSION_DETECTED_ACTION" "EXISTING_SESSION_DETECTED_ACTION"
fetch_and_write_param "/IB_Gateway/ALLOW_BLIND_TRADING" "ALLOW_BLIND_TRADING"
fetch_and_write_param "/IB_Gateway/TIME_ZONE" "TIME_ZONE"
fetch_and_write_param "/IB_Gateway/CUSTOM_CONFIG" "CUSTOM_CONFIG"
fetch_and_write_param "/IB_Gateway/JAVA_HEAP_SIZE" "JAVA_HEAP_SIZE"
fetch_and_write_param "/IB_Gateway/SSH_TUNNEL" "SSH_TUNNEL"
fetch_and_write_param "/IB_Gateway/SSH_OPTIONS" "SSH_OPTIONS"
fetch_and_write_param "/IB_Gateway/SSH_ALIVE_INTERVAL" "SSH_ALIVE_INTERVAL"
fetch_and_write_param "/IB_Gateway/SSH_ALIVE_COUNT" "SSH_ALIVE_COUNT"
fetch_and_write_param "/IB_Gateway/SSH_PASSPHRASE" "SSH_PASSPHRASE"
fetch_and_write_param "/IB_Gateway/SSH_REMOTE_PORT" "SSH_REMOTE_PORT"
fetch_and_write_param "/IB_Gateway/SSH_USER_TUNNEL" "SSH_USER_TUNNEL"
fetch_and_write_param "/IB_Gateway/SSH_RESTART" "SSH_RESTART"
fetch_and_write_param "/IB_Gateway/SSH_VNC_PORT" "SSH_VNC_PORT"

echo ".env file created successfully"
EOF

# Make the script executable
chmod +x /home/ubuntu/create_env_file.sh

# Run the script to create .env file
/home/ubuntu/create_env_file.sh

# Optionally, remove the script after execution
# rm /home/ubuntu/create_env_file.sh
#mkdir /home/ubuntu/ib-gateway-docker/jupyter-work
#chmod 777 /home/ubuntu/ib-gateway-docker/jupyter-work

# EBS device and mount point
EBS_DEVICE="/dev/nvme1n1"  # Adjust if necessary
MOUNT_POINT="/docker_data"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/ebs-mount.log
}

log "Starting EBS volume setup"

# Wait for the EBS volume to be attached
while [ ! -e $EBS_DEVICE ]; do
    log "Waiting for EBS volume to be attached..."
    sleep 5
done


log "Checking EBS device: $EBS_DEVICE"
if [ -e "$EBS_DEVICE" ]; then
    log "EBS device exists"
else
    log "ERROR: EBS device $EBS_DEVICE not found"
    # List available devices
    lsblk
    exit 1
fi

# Check if the volume is already formatted
if ! blkid $EBS_DEVICE; then
    log "Volume is not formatted. Formatting with ext4."
    mkfs -t ext4 $EBS_DEVICE
else
    log "Volume is already formatted. Skipping format."
fi

# Create mount point
mkdir -p $MOUNT_POINT

# Add fstab entry if not already present
if ! grep -q $MOUNT_POINT /etc/fstab; then
    log "Adding fstab entry"
    echo "$EBS_DEVICE $MOUNT_POINT ext4 defaults,nofail 0 2" | tee -a /etc/fstab
else
    log "Fstab entry already exists"
fi

# Mount the volume
if ! mount | grep -q $MOUNT_POINT; then
    log "Mounting volume"
    mount $MOUNT_POINT
else
    log "Volume already mounted"
fi

# Create directories for Docker and Jupyter
mkdir -p $MOUNT_POINT/docker $MOUNT_POINT/jupyter/work $MOUNT_POINT/jupyter/config

# Set permissions (adjust as needed for security)
chown -R 1000:1000 $MOUNT_POINT/jupyter
chmod 755 $MOUNT_POINT/jupyter $MOUNT_POINT/jupyter/work $MOUNT_POINT/jupyter/config

# Configure Docker to use the EBS volume for its data
if [ ! -f /etc/docker/daemon.json ] || ! grep -q "data-root" /etc/docker/daemon.json; then
    log "Configuring Docker to use EBS volume"
    cat << EOF > /etc/docker/daemon.json
{
    "data-root": "$MOUNT_POINT/docker"
}
EOF
    log "Restarting Docker"
    systemctl restart docker
else
    log "Docker already configured to use EBS volume"
fi

log "EBS volume setup complete"

log "Setting up Docker and Jupyter permissions"
sudo usermod -aG docker ubuntu
sudo mkdir -p /docker_data/jupyter/config /docker_data/jupyter/work /docker_data/jupyter/local
sudo chown -R 1000:1000 /docker_data/jupyter
sudo chmod 775 /docker_data/jupyter /docker_data/jupyter/config /docker_data/jupyter/work /docker_data/jupyter/local

# Ensure Docker daemon socket has correct permissions
log "Setting Docker socket permissions"
sudo chmod 666 /var/run/docker.sock

# Create .docker directory with correct permissions
log "Setting up .docker directory"
sudo mkdir -p /home/ubuntu/.docker
sudo chown -R ubuntu:ubuntu /home/ubuntu/.docker
sudo chmod 700 /home/ubuntu/.docker

# Set the public IP address provided by Terraform (placeholder to be replaced)
PUBLIC_IP="${PUBLIC_IP}"

# # Create SSL directory and generate self-signed certificate using the EIP
# echo "Creating SSL directory and generating self-signed certificate for IP: ${PUBLIC_IP}"
# sudo mkdir -p /etc/ssl/certs

# sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#     -keyout /etc/ssl/certs/self-signed.key \
#     -out /etc/ssl/certs/self-signed.pem \
#     -subj "/C=US/ST=NewYork/L=NewYork/O=ExampleOrg/OU=IT/CN=${PUBLIC_IP}"

# # Set permissions to ensure that the ubuntu user can access the certificates
# sudo chmod 644 /etc/ssl/certs/self-signed.*
# sudo chown -R ubuntu:ubuntu /etc/ssl/certs

# echo "Self-signed certificate created for IP: ${PUBLIC_IP}"

# Navigate to the directory containing the docker-compose.yml file
cd /home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution

# Run Docker Compose as the ubuntu user
log "Running docker-compose as ubuntu user"
sudo -u ubuntu docker-compose up -d > /home/ubuntu/compose_output.log 2>&1

# Log completion
echo "Docker Compose has been started with Jupyter and IB Gateway services."



# Message indicating that setup is complete
echo "Docker, Git, and CloudWatch Agent installed, repository cloned. Docker container should be running."
echo "To connect to the VNC server, SSH into the instance and run:"
echo "vncviewer localhost:5900"
echo "You may need to use SSH tunneling to securely connect to the VNC server."