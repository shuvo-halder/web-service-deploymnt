output "instance_id" {
  description = "The ID of the EC2 instance (Add this to GitHub Secrets as EC2_INSTANCE_ID)"
  value       = aws_instance.app_server.id
}

output "public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}