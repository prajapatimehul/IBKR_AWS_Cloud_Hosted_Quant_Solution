#!/bin/bash

# Set the working directory
cd /home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution

# Set your AWS region
AWS_REGION="us-east-1"

# File to write the environment variables
ENV_FILE=".env"

# Clear the existing .env file or create a new one
> $ENV_FILE

# Function to fetch parameter and write to .env file
fetch_and_write_param() {
    local param_name=$1
    local env_var_name=$2
    value=$(aws ssm get-parameter --name "$param_name" --with-decryption --query Parameter.Value --output text --region $AWS_REGION 2>/dev/null)
    if [ $? -eq 0 ] && [ ! -z "$value" ]; then
        # Handle values containing single quotes by escaping them
        escaped_value=$(printf '%s' "$value" | sed "s/'/'\\\\''/g")
        echo "$env_var_name='$escaped_value'" >> $ENV_FILE
    fi
}

# Fetch and write parameters
fetch_and_write_param "/IB_Gateway/TWS_USERID" "TWS_USERID"
fetch_and_write_param "/IB_Gateway/TWS_PASSWORD" "TWS_PASSWORD"
fetch_and_write_param "/IB_Gateway/TRADING_MODE" "TRADING_MODE"
fetch_and_write_param "/IB_Gateway/VNC_SERVER_PASSWORD" "VNC_SERVER_PASSWORD"
fetch_and_write_param "/IB_Gateway/JUPYTER_TOKEN" "JUPYTER_TOKEN"
fetch_and_write_param "/IB_Gateway/TWS_USERID" "TWS_USERID_PAPER"
fetch_and_write_param "/IB_Gateway/TWS_PASSWORD" "TWS_PASSWORD_PAPER"
#advanced parameters
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

# Add more fetch_and_write_param calls for other parameters as needed

# Check if the .env file was updated successfully
if [ ! -s "$ENV_FILE" ]; then
    echo "Failed to update .env file or file is empty. Exiting."
    exit 1
fi

echo ".env file updated successfully."

# Stop the running Docker containers
echo "Stopping Docker containers..."
docker-compose down

# Wait for 10 seconds
echo "Waiting for 10 seconds before starting containers..."
sleep 10

# Start the Docker containers again
echo "Starting Docker containers..."
docker-compose up -d

echo "Environment updated and Docker containers restarted."