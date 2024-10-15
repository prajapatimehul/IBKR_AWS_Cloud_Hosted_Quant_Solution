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


echo "setting up or changing security options to access Jupyter, Ib_Gateway etc"
echo ""

# Step 1: Prompt the user for their preferred IP configuration
echo "Please select your preferred security group configuration:"
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
terraform apply -var="my_ip=${IP_CIDR}"

# Completion message
echo "Deployment complete! Security group is configured with IP/CIDR: $IP_CIDR"


echo -e "${YELLOW}Finished Terraform deployment...${NC}"

# # Initialize Terraform
# echo -e "\n${YELLOW}Initializing Terraform...${NC}"
# terraform init

# if [ $? -ne 0 ]; then
#     echo -e "${RED}Terraform initialization failed. Exiting.${NC}"
#     exit 1
# fi

# # Show the plan
# echo -e "\n${YELLOW}Generating Terraform plan...${NC}"
# terraform plan

# if [ $? -ne 0 ]; then
#     echo -e "${RED}Terraform plan generation failed. Exiting.${NC}"
#     exit 1
# fi

# # Prompt for confirmation
# echo -e "\n${YELLOW}Do you want to apply this plan? (y/n)${NC}"
# read -r response
# if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
# then
#     echo -e "\n${YELLOW}Applying Terraform plan...${NC}"
#     terraform apply

#     if [ $? -ne 0 ]; then
#         echo -e "${RED}Terraform apply failed.${NC}"
#         exit 1
#     fi
# else
#     echo -e "${YELLOW}Deployment cancelled.${NC}"
#     exit 0
# fi

# # Output important information
# echo -e "\n${GREEN}Deployment complete. Important outputs:${NC}"
# terraform output

# echo -e "\n${GREEN}Deployment script finished successfully.${NC}"