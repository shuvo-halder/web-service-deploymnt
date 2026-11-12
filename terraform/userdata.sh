#!/bin/bash
set -ex

# Update OS and install Docker
dnf update -y
dnf install -y docker
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group (optional, for SSM debugging)
usermod -aG docker ec2-user

# Pull and run the container using AWS CloudWatch logs driver
# Note: For private GHCR repos, you would need to run `docker login` first using a PAT stored in AWS Parameter Store.
docker run -d \
  --name web-app \
  -p ${app_port}:${app_port} \
  --restart=unless-stopped \
  --log-driver=awslogs \
  --log-opt awslogs-region=${aws_region} \
  --log-opt awslogs-group=${log_group_name} \
  ghcr.io/shuvo-halder/web-service-deploymnt:main || echo "Image not found yet, pipeline will deploy it"