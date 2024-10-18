cd infra
pwd
terraform taint aws_instance.docker && terraform apply -auto-approve