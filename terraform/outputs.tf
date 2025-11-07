# Output the private key - this is your PEM file content
# This will be used by Jenkins pipeline to save the .pem file
# IMPORTANT: Keep this key secure and never commit it to Git!
output "private_key" {
  description = "Private key to SSH into EC2 instance"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true  # Marks as sensitive so it won't show in logs
}

# Output the public IP address of your EC2 instance
# Use this IP to connect to your instance via SSH
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}

# Output the instance ID
# Useful for identifying your instance in AWS Console
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web_server.id
}

# Output the SSH connection command
# Copy and paste this command to connect to your instance
output "ssh_connection" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i my-ec2-key.pem ec2-user@${aws_instance.web_server.public_ip}"
}

# Output the security group ID
# Useful if you need to modify firewall rules later
output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.ec2_sg.id
}
