variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH to the instance (e.g., 203.0.113.10/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Extra resource tags as a JSON map"
  type        = map(string)
  default     = {
    Project = "JenkinsTF"
    Env     = "Dev"
  }
}
