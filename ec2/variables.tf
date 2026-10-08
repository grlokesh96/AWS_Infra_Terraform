variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "Ubuntu 22.04 AMI ID for the target region"
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name. Leave unset to launch without one; only needed once allowed_ssh_cidrs is opened up."
  type        = string
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to reach the instance on port 22. Defaults to an empty list, which disables SSH ingress entirely."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_ssh_cidrs : can(cidrhost(c, 0))])
    error_message = "Each entry in allowed_ssh_cidrs must be a valid CIDR block, e.g. \"203.0.113.10/32\"."
  }
}

variable "allowed_web_cidrs" {
  description = "CIDR blocks allowed to reach the instance on ports 80 and 443."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for c in var.allowed_web_cidrs : can(cidrhost(c, 0))])
    error_message = "Each entry in allowed_web_cidrs must be a valid CIDR block, e.g. \"0.0.0.0/0\"."
  }
}
