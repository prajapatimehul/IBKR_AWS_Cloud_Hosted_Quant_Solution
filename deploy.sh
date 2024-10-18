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

# Step 1: Check if Terraform is installed
if ! command_exists terraform; then
    echo -e "${YELLOW}Terraform is not installed. Would you like to install it? (y/n)${NC}"
    read -r install_terraform
    if [[ "$install_terraform" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        echo -e "${YELLOW}Installing Terraform...${NC}"
        
        # Check the operating system and install accordingly
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux installation
            sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
            curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
            sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
            sudo apt-get update && sudo apt-get install terraform
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS installation
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
        
        # Check if Terraform was installed successfully
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

#create random generated token for Jupyter if one does not exist
generate_random_string() {
    local length=$1
    tr -dc A-Za-z0-9 </dev/urandom | head -c $length
}
check_and_create_jupyter_token() {
    local param_name="/IB_Gateway/JUPYTER_TOKEN"
    if ! aws ssm get-parameter --name "$param_name" --with-decryption >/dev/null 2>&1; then
        echo -e "${YELLOW}Parameter $param_name not found. Creating it...${NC}"
        local random_token=$(generate_random_string 22)
        aws ssm put-parameter --name "$param_name" --type "SecureString" --value "$random_token" --overwrite
        echo -e "${GREEN}Created parameter $param_name with a new random token.${NC}"
        echo "JUPYTER_TOKEN=$random_token" >> jupyter_token.txt
    else
        echo -e "${GREEN}Parameter $param_name already exists.${NC}"
    fi
}

# Step 2: Check if the required parameters exist in AWS SSM Parameter Store, if not run Python script
required_params=(
    "/IB_Gateway/TWS_USERID"
    "/IB_Gateway/TWS_PASSWORD"
    "/IB_Gateway/TRADING_MODE"
    "/IB_Gateway/VNC_SERVER_PASSWORD"
    "/IB_Gateway/JUPYTER_TOKEN"
    "/IB_Gateway/TWS_USERID_PAPER"
    "/IB_Gateway/TWS_PASSWORD_PAPER"
)

echo -e "${YELLOW}Checking for required parameters in AWS Systems Manager Parameter Store...${NC}"

missing_params=false
for param in "${required_params[@]}"; do
    aws ssm get-parameter --name "$param" --with-decryption > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Parameter $param not found!${NC}"
        missing_params=true
    fi
done

# If any parameter is missing, run the Python script to update and get the config
if [ "$missing_params" = true ]; then
    echo -e "${YELLOW}Some parameters are missing. Running update_and_get_config.py to fetch them...${NC}"
    python3 ./update_and_get_config.py
    check_status "Failed to fetch missing parameters"
fi

check_and_create_jupyter_token

# Step 3: Check if the S3 bucket for Terraform state management exists
bucket_prefix="quant-terraform-state-bucket"

existing_bucket=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, '$bucket_prefix')].Name" --output text)
if [ -z "$existing_bucket" ]; then
    echo -e "${YELLOW}No existing S3 bucket found for state management, applying Terraform for S3 and DynamoDB setup...${NC}"
    cd ./s3_dynamo_for_statemanagement
    terraform init
    terraform apply -auto-approve
    check_status "Failed to create S3 bucket and DynamoDB for state management"
    existing_bucket=$(terraform output -raw bucket_name)
else
    echo -e "${GREEN}Existing S3 bucket found: $existing_bucket${NC}"
fi

# Step 4: Retrieve S3 bucket name and DynamoDB table name from state-management outputs
echo -e "${YELLOW}Retrieving S3 bucket name and DynamoDB table name from state-management outputs...${NC}"

cd   s3_dynamo_for_statemanagement

# Get the S3 bucket name
bucket_name=$(terraform output -raw bucket_name)
check_status "Failed to retrieve bucket name"

# Get the DynamoDB table name
dynamodb_table_name=$(terraform output -raw dynamodb_table_name)
check_status "Failed to retrieve DynamoDB table name"

# Step 5: Initialize and apply the EBS module with dynamic backend values
echo -e "${YELLOW}Initializing EBS module...${NC}"

cd ../ebs_storage

terraform init \
  -backend-config="bucket=$bucket_name" \
  -backend-config="key=ebs/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=$dynamodb_table_name" \
  -backend-config="encrypt=true"
check_status "Failed to initialize EBS module"

echo -e "${YELLOW}Applying EBS module...${NC}"
terraform apply -auto-approve
check_status "Failed to apply EBS module"

# Step 6: Initialize and apply the Infrastructure module with dynamic backend values
echo -e "${YELLOW}Initializing Infrastructure module...${NC}"

cd ../infra

terraform init \
  -backend-config="bucket=$bucket_name" \
  -backend-config="key=infrastructure/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=$dynamodb_table_name" \
  -backend-config="encrypt=true"
check_status "Failed to initialize Infrastructure module"

echo -e "${YELLOW}Applying Infrastructure module...${NC}"


echo "setting up or changing security options to access Jupyter, Ib_Gateway etc"
echo ""

# Step 1: Prompt the user for their preferred IP configuration
echo "Please select your preferred security group configuration:"
echo ""
echo "1) Use your current IP address (recommended)"
echo "2) Specify a new list of IP addresses or ranges (comma-separated)"
echo "3) Open to all (0.0.0.0/0) [Not Recommended]"
echo
read -p "Enter your choice (1/2/3): " choice

# Step 2: Handle the user's choice
case $choice in
  1)
    # Default: Use the current public IP address
    MY_IP=$(curl -4 -s ifconfig.me)
    IP_CIDR="${MY_IP}/32"
    echo "Your current IP address ($MY_IP) will be used for the security group."
    ;;

  2)
    # Prompt for a list of IP addresses or ranges
    read -p "Enter the list of IP addresses or CIDR ranges (comma-separated): " ip_list
    IP_CIDR=$(echo "$ip_list" | sed 's/ //g')  # Remove spaces if any
    echo "The following IP addresses/ranges will be used: $IP_CIDR"
    ;;

  3)
    # Use 0.0.0.0/0 (open to the world) - Use with caution!
    IP_CIDR="0.0.0.0/0"
    echo "WARNING: The security group will be open to ALL IP addresses (0.0.0.0/0)."
    ;;

  *)
    # Invalid choice, use the current IP as default
    echo "Invalid choice. Defaulting to use your current IP address."
    MY_IP=$(curl -4 -s ifconfig.me)
    IP_CIDR="${MY_IP}/32"
    echo "Your current IP address ($MY_IP) will be used for the security group."
    ;;
esac

# # Step 3: Run Terraform plan with the chosen IP address or range
# echo "Running Terraform plan with IP/CIDR: $IP_CIDR"
# terraform plan -var="my_ip=${IP_CIDR}"

# Step 4: Apply the configuration to update the security group
echo "Applying Terraform configuration to update the security group..."
terraform apply  -var "my_ip=${IP_CIDR}" -auto-approve

# Completion message
echo "Deployment complete! Security group is configured with IP/CIDR: $IP_CIDR"
if [ -f jupyter_token.txt ]; then
    echo -e "${GREEN}Newly created Jupyter token please use this for access to Jupyter, please copy it safely somewhere :${NC}"
    cat jupyter_token.txt
    rm jupyter_token.txt
fi

