variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., ap-south-1)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Instance type must be one of: t2.micro, t3.micro, t3.small, t3.medium."
  }
}

variable "ssh_ingress_cidr" {
  description = "CIDR block allowed to SSH (use your IP/32 for security)"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.ssh_ingress_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 203.0.113.10/32 or 0.0.0.0/0)."
  }
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default = {
    Project     = "JenkinsTerraform"
    Environment = "Development"
  }
}
