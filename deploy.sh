#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a command was successful
check_status() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: $1${NC}"
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate random string for Jupyter token
generate_jupyter_token() {
    local length=${1:-32}
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c "$length"
    elif [ -f /dev/urandom ]; then
        LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
    else
        local result=""
        local characters='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        for ((i=0; i<length; i++)); do
            result+=${characters:$((RANDOM % ${#characters})):1}
        done
        echo "$result"
    fi
}


read_secure_input() {
    local prompt="$1"
    local value
    read -s -p "$prompt" value
    echo  # New line after secure input
    # Trim whitespace and newlines
    value=$(echo "$value" | tr -d '\n' | tr -d '\r')
    echo "$value"
}

# Function to validate trading mode
validate_trading_mode() {
    local mode="$1"
    if [[ "$mode" == "paper" || "$mode" == "live" ]]; then
        return 0
    fi
    return 1
}

# Function to create SSM parameter
create_ssm_parameter() {
    local param_name="$1"
    local param_value="$2"
    local is_secure="$3"
    
    # Sanitize the parameter value (remove newlines and carriage returns)
    param_value=$(echo "$param_value" | tr -d '\n' | tr -d '\r')
    
    local param_type="String"
    if [ "$is_secure" = true ]; then
        param_type="SecureString"
    fi
    
    if aws ssm put-parameter \
        --name "$param_name" \
        --type "$param_type" \
        --value "$param_value" \
        --overwrite > /dev/null 2>&1; then
        echo -e "${GREEN}Successfully created parameter: $param_name${NC}"
        return 0
    else
        echo -e "${RED}Failed to create parameter: $param_name${NC}"
        return 1
    fi
}

# Function to check and create Jupyter token
check_and_create_jupyter_token() {
    local param_name="/IB_Gateway/JUPYTER_TOKEN"
    
    if ! command -v aws >/dev/null 2>&1; then
        echo -e "${YELLOW}Error: AWS CLI is not installed${NC}"
        return 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${YELLOW}Error: AWS credentials not configured correctly${NC}"
        return 1
    fi
    
    if ! aws ssm get-parameter --name "$param_name" --with-decryption > /dev/null 2>&1; then
        echo -e "${YELLOW}Jupyter token not found. Generating new token...${NC}"
        
        local random_token
        random_token=$(generate_jupyter_token 32) || {
            echo -e "${YELLOW}Error generating random token${NC}"
            return 1
        }
        
        if create_ssm_parameter "$param_name" "$random_token" true; then
            echo -e "${GREEN}Created new Jupyter token${NC}"
            echo "JUPYTER_TOKEN=$random_token" > jupyter_token.txt
            echo -e "${GREEN}Token saved to jupyter_token.txt${NC}"
        else
            return 1
        fi
    else
        echo -e "${GREEN}Jupyter token already exists in Parameter Store${NC}"
    fi
}

# Function to check and create required parameters
check_and_create_parameters() {
   # Define parameters
   local required_params=(
       "/IB_Gateway/TWS_USERID"
       "/IB_Gateway/TWS_PASSWORD"
       "/IB_Gateway/TRADING_MODE" 
       "/IB_Gateway/VNC_SERVER_PASSWORD"
       "/IB_Gateway/TWS_USERID_PAPER"
       "/IB_Gateway/TWS_PASSWORD_PAPER"
   )
   
   echo -e "${YELLOW}Checking for required parameters in AWS Systems Manager Parameter Store...${NC}"
   
   for param in "${required_params[@]}"; do
       # Check if parameter exists and get its type
       param_type=$(aws ssm get-parameter --name "$param" --query 'Parameter.Type' --output text 2>/dev/null)
       param_exists=$?
       
       if [ $param_exists -eq 0 ]; then
           # Parameter exists, check if it's SecureString
           if [ "$param_type" != "SecureString" ]; then
               echo -e "${YELLOW}Parameter $param exists but is not secure (Type: $param_type)${NC}"
               # Get current value
               current_value=$(aws ssm get-parameter --name "$param" --with-decryption --query 'Parameter.Value' --output text)
               
               # Delete the existing parameter
               aws ssm delete-parameter --name "$param"
               
               # Recreate as SecureString
               if create_ssm_parameter "$param" "$current_value" true; then
                   echo -e "${GREEN}Parameter $param converted to SecureString${NC}"
               else
                   echo -e "${RED}Failed to convert $param to SecureString${NC}"
                   return 1
               fi
           else
               echo -e "${GREEN}Parameter $param exists and is secure${NC}"
           fi
       else
           echo -e "${YELLOW}Parameter $param not found!${NC}"
           local param_name=$(basename "$param")
           local value=""
           
           # Handle parameter input
           if [ "$param" == "/IB_Gateway/TRADING_MODE" ]; then
               while true; do
                   value=$(read_secure_input "Enter trading mode (paper/live/both): ")
                   if [[ "$value" == "paper" || "$value" == "live" || "$value" == "both" ]]; then
                       break
                   fi
                   echo -e "${YELLOW}Invalid input. Trading mode must be 'paper', 'live', or 'both'.${NC}"
               done
           else
               value=$(read_secure_input "Enter value for $param_name: ")
           fi
           
           # Create as SecureString
           if ! create_ssm_parameter "$param" "$value" true; then
               return 1
           fi
       fi
   done
   
   echo -e "${GREEN}All required parameters are now set as SecureString in AWS SSM Parameter Store${NC}"
   return 0
}
# Main script execution starts here
# Step 1: Check if Terraform is installed
if ! command_exists terraform; then
    echo -e "${YELLOW}Terraform is not installed. Would you like to install it? (y/n)${NC}"
    read -r install_terraform
    if [[ "$install_terraform" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        echo -e "${YELLOW}Installing Terraform...${NC}"
        
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
            curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
            sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
            sudo apt-get update && sudo apt-get install terraform
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if ! command_exists brew; then
                echo -e "${YELLOW}Homebrew is not installed. Installing Homebrew first...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                check_status "Failed to install Homebrew."
            fi
            brew tap hashicorp/tap
            brew install hashicorp/tap/terraform
        else
            echo -e "${RED}Unsupported operating system. Please install Terraform manually.${NC}"
            exit 1
        fi
        
        if ! command_exists terraform; then
            echo -e "${RED}Terraform installation failed. Please install it manually.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Terraform is required to run this script. Exiting.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Terraform is already installed.${NC}"
fi

# Step 2: Check and create Jupyter token first
check_and_create_jupyter_token
check_status "Failed to check/create Jupyter token"

# Step 3: Check and create other required parameters
check_and_create_parameters
check_status "Failed to check/create required parameters"

# Step 4: Check if the S3 bucket for Terraform state management exists
bucket_prefix="quant-terraform-state-bucket"

existing_bucket=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, '$bucket_prefix')].Name" --output text)
if [ -z "$existing_bucket" ]; then
    echo -e "${YELLOW}No existing S3 bucket found for state management, applying Terraform for S3 and DynamoDB setup...${NC}"
    cd ./s3_dynamo_for_statemanagement || exit 1
    terraform init
    terraform apply -auto-approve 
    check_status "Failed to create S3 bucket and DynamoDB for state management"
    existing_bucket=$(terraform output -raw bucket_name)
else
    echo -e "${GREEN}Existing S3 bucket found: $existing_bucket${NC}"
fi

# Step 5: Retrieve S3 bucket name and DynamoDB table name
echo -e "${YELLOW}Retrieving S3 bucket name and DynamoDB table name from state-management outputs...${NC}"

cd s3_dynamo_for_statemanagement || exit 1

bucket_name=$(terraform output -raw bucket_name)
check_status "Failed to retrieve bucket name"

dynamodb_table_name=$(terraform output -raw dynamodb_table_name)
check_status "Failed to retrieve DynamoDB table name"

# Step 6: Initialize and apply the EBS module
echo -e "${YELLOW}Initializing EBS module...${NC}"

cd ../ebs_storage || exit 1

terraform init \
    -backend-config="bucket=$bucket_name" \
    -backend-config="key=ebs/terraform.tfstate" \
    -backend-config="region=us-east-1" \
    -backend-config="dynamodb_table=$dynamodb_table_name" \
    -backend-config="encrypt=true"
check_status "Failed to initialize EBS module"

echo -e "${YELLOW}Applying EBS module...${NC}"
terraform apply -auto-approve -lock=false
check_status "Failed to apply EBS module"

# Step 7: Initialize and apply the Infrastructure module
echo -e "${YELLOW}Initializing Infrastructure module...${NC}"

cd ../infra || exit 1

terraform init \
    -backend-config="bucket=$bucket_name" \
    -backend-config="key=infrastructure/terraform.tfstate" \
    -backend-config="region=us-east-1" \
    -backend-config="dynamodb_table=$dynamodb_table_name" \
    -backend-config="encrypt=true"
check_status "Failed to initialize Infrastructure module"

echo -e "${YELLOW}Applying Infrastructure module...${NC}"

# Step 8: Security group configuration
echo "Setting up or changing security options to access Jupyter, IB_Gateway etc"
echo ""
echo "Please select your preferred security group configuration:"
echo "1) Use your current IP address (recommended)"
echo "2) Specify a new list of IP addresses or ranges (comma-separated)"
echo "3) Open to all (0.0.0.0/0) [Not Recommended]"
echo "If no choice is made within 5 seconds, defaulting to option 1."
read -t 5 -p "Enter your choice (1/2/3): " choice

# Default to choice 1 if no input is provided
choice=${choice:-1}

case $choice in
    1)
        MY_IP=$(curl -4 -s ifconfig.me)
        IP_CIDR="${MY_IP}/32"
        echo "Your current IP address ($MY_IP) will be used for the security group."
        ;;
    2)
        read -p "Enter the list of IP addresses or CIDR ranges (comma-separated): " ip_list
        IP_CIDR=$(echo "$ip_list" | sed 's/ //g')
        echo "The following IP addresses/ranges will be used: $IP_CIDR"
        ;;
    3)
        IP_CIDR="0.0.0.0/0"
        echo "WARNING: The security group will be open to ALL IP addresses (0.0.0.0/0)."
        ;;
    *)
        echo "Invalid choice. Defaulting to use your current IP address."
        MY_IP=$(curl -4 -s ifconfig.me)
        IP_CIDR="${MY_IP}/32"
        echo "Your current IP address ($MY_IP) will be used for the security group."
        ;;
esac

echo "Applying Terraform configuration to update the security group..."
terraform apply -var "my_ip=${IP_CIDR}" -auto-approve -lock=false
check_status "Failed to apply infrastructure module"

# Completion message
echo "Deployment complete! Security group is configured with IP/CIDR: $IP_CIDR"
if [ -f jupyter_token.txt ]; then
    echo -e "${GREEN}Newly created Jupyter token (please copy it safely somewhere):${NC}"
    cat jupyter_token.txt
    rm jupyter_token.txt
fi