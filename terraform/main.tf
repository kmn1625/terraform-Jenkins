# Configure the AWS Provider
# This tells Terraform to use AWS and which region to create resources in
provider "aws" {
  region = var.aws_region
}

# Generate a new private key
# This creates a new RSA key pair (private and public keys)
# The private key will be used to connect to your EC2 instance via SSH
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair using the generated public key
# This uploads the public key to AWS so it can be assigned to your EC2 instance
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Create a Security Group to control traffic to the EC2 instance
# This acts as a virtual firewall for your instance
resource "aws_security_group" "ec2_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security group for EC2 instance - allows SSH access"

  # Ingress rule - allows incoming SSH traffic (port 22)
  # This lets you connect to your instance from anywhere
  # WARNING: 0.0.0.0/0 allows access from any IP - restrict this in production!
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Change to your IP for better security: ["YOUR_IP/32"]
  }

  # Egress rule - allows all outgoing traffic
  # This lets your instance connect to the internet and download updates
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-security-group"
  }
}

# Create the EC2 Instance
# This is the actual virtual machine that will be created in AWS
resource "aws_instance" "web_server" {
  # AMI (Amazon Machine Image) - the operating system image
  # This uses Amazon Linux 2023 - you can change to Ubuntu or other OS
  ami           = var.ami_id
  
  # Instance type - defines CPU, memory, and network capacity
  # t2.micro is free tier eligible (750 hours/month free for 12 months)
  instance_type = var.instance_type
  
  # Associate the key pair we created above
  # This allows you to SSH into the instance using the private key
  key_name      = aws_key_pair.ec2_key_pair.key_name
  
  # Associate the security group we created above
  # This applies the firewall rules to allow SSH access
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Root volume configuration - the main disk for your instance
  root_block_device {
    volume_size = 8  # Size in GB - 8GB is usually enough for basic usage
    volume_type = "gp3"  # General Purpose SSD
  }

  # Tags to identify your instance in AWS console
  tags = {
    Name        = var.instance_name
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}
