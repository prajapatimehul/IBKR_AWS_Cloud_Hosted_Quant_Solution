# Deployment Guide for IBKR AWS Cloud Hosted Quant Solution

This guide provides detailed steps to deploy the `IBKR_AWS_Cloud_Hosted_Quant_Solution` project, including setting up the base environment, deploying IB Gateway and Jupyter components, and testing the deployment.

## Step 1: Set Up the Base Environment

1. **Run the `deploy.sh` Script**:
   - This script sets up the necessary AWS infrastructure and parameters.
   - It checks and creates required AWS SSM parameters, initializes and applies Terraform modules, and configures security groups.
   - Execute the script to ensure all base components are properly configured.

## Step 2: Deploy IB Gateway Docker

1. **Clone the `ib-gateway-docker` Repository**:
   - Clone the repository to your local machine to access the necessary files and configurations.

2. **Create Docker Compose File**:
   - Create a `docker-compose.yml` file to define the IB Gateway service, including environment variables for user credentials, trading mode, and VNC server password.
   - Configure the ports and volumes for the IB Gateway container.

3. **Run Docker Compose**:
   - Use Docker Compose to start the IB Gateway container, ensuring it runs in the background.

## Step 3: Deploy Jupyter Quant Docker

1. **Clone the `jupyter-quant` Repository**:
   - Clone the repository to your local machine to access the necessary files and configurations.

2. **Create Docker Compose File**:
   - Create a `docker-compose.yml` file to define the Jupyter Quant service, including ports and volumes for data, configuration, and notebooks.

3. **Run Docker Compose**:
   - Use Docker Compose to start the Jupyter Quant container, ensuring it runs in the background.

## Step 4: Test the Deployment

1. **Access IB Gateway**:
   - Connect to the VNC server using a VNC client to interact with the IB Gateway user interface.
   - Use the VNC password set in the Docker Compose file to log in.

2. **Access Jupyter Notebook**:
   - Open your web browser and navigate to the Jupyter Notebook URL.
   - Use the token provided in the terminal output to log in and start using the Jupyter environment.

By following these steps, you will have successfully deployed the IB Gateway and Jupyter environment on AWS. You can now test the setup using VNC and your web browser to ensure everything is working as expected.