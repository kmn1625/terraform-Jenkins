terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Ubuntu 22.04 LTS (Jammy) x86_64 AMI by Canonical
# Owner: Canonical (099720109477)
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]
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

# Default VPC & subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Generate SSH keypair locally (PEM) and upload public key as EC2 key pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  key_name   = "jenkins-ec2-generated"
  public_key = tls_private_key.ssh.public_key_openssh
  tags       = var.tags
}

# Save private key to a local file (sensitive); Jenkins will archive it
resource "local_sensitive_file" "pem" {
  filename        = "${path.module}/jenkins-ec2.pem"
  content         = tls_private_key.ssh.private_key_pem
  file_permission = "0600"
}

# Security group allowing SSH only from provided CIDR
resource "aws_security_group" "ec2_sg" {
  name        = "jenkins-tf-ec2-sg"
  description = "SSH access for Jenkins Terraform demo (Ubuntu)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge({ Name = "jenkins-tf-ec2-sg" }, var.tags)
}

# Pick the first subnet for the instance (POC)
locals {
  subnet_id = element(data.aws_subnets.default.ids, 0)
}

resource "aws_instance" "vm" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  key_name = aws_key_pair.generated.key_name

  user_data = <<-EOT
              #!/bin/bash
              echo "Provisioned by Terraform via Jenkins (Ubuntu 22.04)" > /etc/motd
              EOT

  tags = merge({ Name = "jenkins-tf-ubuntu-ec2" }, var.tags)
}

