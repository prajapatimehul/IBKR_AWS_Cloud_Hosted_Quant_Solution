#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color


cd infra
echo -e "${GREEN}Destroying the EC2 instance...${NC}"

terraform destroy -target=aws_instance.docker -target=aws_eip.docker_eip -auto-approve -lock=false


if [ $? -eq 0 ]; then
    echo -e "${GREEN}EC2 instance destroyed successfully.${NC}"
else
    echo -e "${RED}Failed to destroy EC2 instance.${NC}"
    exit 1
fi
cd ..