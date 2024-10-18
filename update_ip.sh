echo -e "${YELLOW}Initializing Infrastructure module...${NC}"

cd infra

# terraform init \
#   -backend-config="bucket=$bucket_name" \
#   -backend-config="key=infrastructure/terraform.tfstate" \
#   -backend-config="region=us-east-1" \
#   -backend-config="dynamodb_table=$dynamodb_table_name" \
#   -backend-config="encrypt=true"
# check_status "Failed to initialize Infrastructure module"

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

