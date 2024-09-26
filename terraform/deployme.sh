#!/bin/bash

# Ensure we're in the script's directory
cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Terraform is installed
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
fi

echo -e "${YELLOW}Starting Terraform deployment...${NC}"

# Initialize Terraform
echo -e "\n${YELLOW}Initializing Terraform...${NC}"
terraform init

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform initialization failed. Exiting.${NC}"
    exit 1
fi

# Show the plan
echo -e "\n${YELLOW}Generating Terraform plan...${NC}"
terraform plan

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform plan generation failed. Exiting.${NC}"
    exit 1
fi

# Prompt for confirmation
echo -e "\n${YELLOW}Do you want to apply this plan? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
    echo -e "\n${YELLOW}Applying Terraform plan...${NC}"
    terraform apply

    if [ $? -ne 0 ]; then
        echo -e "${RED}Terraform apply failed.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    exit 0
fi

# Output important information
echo -e "\n${GREEN}Deployment complete. Important outputs:${NC}"
terraform output

echo -e "\n${GREEN}Deployment script finished successfully.${NC}"