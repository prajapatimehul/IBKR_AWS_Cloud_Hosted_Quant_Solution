#!/bin/bash

# Set your AWS region
AWS_REGION="us-east-1"

# Set the tag key and value to identify your instance
TAG_KEY="Name"
TAG_VALUE="QuantInstance"

# Find the instance ID based on the tag
INSTANCE_ID=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].[InstanceId]" \
    --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "No running instance found with tag $TAG_KEY=$TAG_VALUE"
    exit 1
fi

echo "Found instance: $INSTANCE_ID"

# Send the command to the instance
COMMAND_ID=$(aws ssm send-command \
    --region $AWS_REGION \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["chmod +x /home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution/update_and_restart.sh", "/home/ubuntu/IBKR_AWS_Cloud_Hosted_Quant_Solution/update_and_restart.sh"]' \
    --output text \
    --query "Command.CommandId")

echo "Command sent. Command ID: $COMMAND_ID"

# Wait for the command to complete
aws ssm wait command-executed \
    --region $AWS_REGION \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID"

# Get the command status
STATUS=$(aws ssm list-command-invocations \
    --region $AWS_REGION \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "CommandInvocations[0].Status" \
    --output text)

echo "Command execution completed with status: $STATUS"

# Get command output, including error output
OUTPUT=$(aws ssm get-command-invocation \
    --region $AWS_REGION \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "[StandardOutputContent, StandardErrorContent]" \
    --output text)

echo "Command output:"
echo "$OUTPUT"

# If the command failed, get more details
if [ "$STATUS" == "Failed" ]; then
    ERROR_DETAILS=$(aws ssm get-command-invocation \
        --region $AWS_REGION \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query "StandardErrorContent" \
        --output text)
    
    echo "Error details:"
    echo "$ERROR_DETAILS"
fi