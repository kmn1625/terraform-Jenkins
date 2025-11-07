terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Pipeline  = "Jenkins"
    }
  }
}

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Use default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Generate SSH key pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  key_name   = "jenkins-ec2-key-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = merge(
    var.tags,
    {
      Name = "jenkins-generated-keypair"
    }
  )

  lifecycle {
    ignore_changes = [key_name]
  }
}

# Save private key locally (Jenkins will archive this)
resource "local_sensitive_file" "pem" {
  filename        = "${path.module}/jenkins-ec2.pem"
  content         = tls_private_key.ssh.private_key_pem
  file_permission = "0600"
}

# Security group for SSH access
resource "aws_security_group" "ec2_sg" {
  name_prefix = "jenkins-tf-ec2-"
  description = "Allow SSH access to EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  egress {
    description      = "Allow all outbound"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "jenkins-tf-ec2-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Instance
resource "aws_instance" "vm" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated.key_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              apt-get update
              
              # Set hostname
              hostnamectl set-hostname jenkins-terraform-vm
              
              # Create MOTD
              cat > /etc/motd << 'MOTD'
              ================================================
              Welcome to Jenkins-Terraform Provisioned VM
              OS: Ubuntu 22.04 LTS
              Provisioned: $(date)
              ================================================
              MOTD
              
              echo "VM provisioned successfully" > /var/log/terraform-init.log
              EOF

  tags = merge(
    var.tags,
    {
      Name = "jenkins-terraform-ubuntu-vm"
    }
  )

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Output the connection details
output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.vm.id
}

output "instance_public_ip" {
  description = "Public IP address"
  value       = aws_instance.vm.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name"
  value       = aws_instance.vm.public_dns
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i jenkins-ec2.pem ubuntu@${aws_instance.vm.public_ip}"
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.ec2_sg.id
}

output "key_pair_name" {
  description = "Name of the generated key pair"
  value       = aws_key_pair.generated.key_name
}
