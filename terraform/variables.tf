# AWS Region where resources will be created
# Common regions: us-east-1 (Virginia), us-west-2 (Oregon), ap-south-1 (Mumbai)
variable "aws_region" {
  description = "AWS region to create resources"
  type        = string
  default     = "us-east-1"  # Change to your preferred region
}

# AMI ID for the EC2 instance
# This is the operating system image
# Below is Amazon Linux 2023 for us-east-1
# Find AMI IDs: AWS Console > EC2 > Launch Instance > Select OS
variable "ami_id" {
  description = "AMI ID for EC2 instance (Amazon Linux 2023)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2023 - us-east-1
  # For other regions, find AMI ID in AWS Console
  # Mumbai (ap-south-1): ami-0f5ee92e2d63afc18
  # Oregon (us-west-2): ami-0c55b159cbfafe1f0
}

# Instance type - defines the size/capacity of your virtual machine
# t2.micro: 1 vCPU, 1 GB RAM - Free tier eligible
# t3.micro: 2 vCPU, 1 GB RAM - Better performance
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"  # Free tier eligible
}

# Name for your EC2 instance
# This will appear in AWS Console
variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "MyWebServer"
}

# Name for the SSH key pair
# This is how AWS identifies your key
variable "key_name" {
  description = "Name for the SSH key pair"
  type        = string
  default     = "my-ec2-keypair"
}
