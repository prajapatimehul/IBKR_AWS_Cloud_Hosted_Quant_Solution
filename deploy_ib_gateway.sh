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

# Start Docker
if ! sudo systemctl start docker; then
    log "ERROR: Failed to start Docker"
    sudo systemctl status docker
    exit 1
fi

sudo systemctl start docker
sudo usermod -aG docker ubuntu

# Install AWS CLI
sudo apt-get install -y awscli

# Install Git
sudo apt-get install git -y

# Clone the repository
# if ! git clone https://github.com/Jamesd000/IBKR_AWS_Cloud_Hosted_Quant_Solution.git; then
#     log "ERROR: Git clone failed"
#     git --version
#     ping -c 1 github.com
#     exit 1
# fi

cd /home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution

# Create a script to fetch parameters from AWS Parameter Store and create .env file
cat << 'EOF' > /home/ubuntu/create_env_file.sh
#!/bin/bash

# Set your AWS region
AWS_REGION="us-east-1"

# File to write the environment variables
#ENV_FILE="/home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution/.env"
ENV_FILE="/home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution/.env"

# Clear the existing .env file or create a new one
> $ENV_FILE

# Function to fetch parameter and write to .env file
fetch_and_write_param() {
    local param_name=$1
    local env_var_name=$2
    # Use single quotes around the aws command to prevent $ interpretation
    value=$(aws ssm get-parameter --name "$param_name" --with-decryption --query Parameter.Value --output text --region $AWS_REGION 2>/dev/null)
    if [ $? -eq 0 ] && [ ! -z "$value" ]; then
        # Use printf to preserve special characters including $
        printf "%s=%s\n" "$env_var_name" "'$value'" >> $ENV_FILE
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

chmod +x /home/ubuntu/create_env_file.sh

# Run the script to create .env file
/home/ubuntu/create_env_file.sh

# Run Docker Compose as the ubuntu user
log "Running docker-compose as ubuntu user"
sudo -u ubuntu docker-compose up -d > /home/ubuntu/compose_output.log 2>&1

# Log completion
echo "Docker Compose has been started with IB Gateway services."

# Message indicating that setup is complete
echo "Docker, Git, and repository setup complete. Docker container should be running."