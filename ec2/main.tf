# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get a subnet from the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "terraform-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  # SSH is disabled unless an operator opts in with their own CIDR.
  dynamic "ingress" {
    for_each = var.allowed_ssh_cidrs

    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # tfsec:ignore:AVD-AWS-0107 Intentional: this is a public web server, ports 80/443 must be reachable from the internet.
  dynamic "ingress" {
    for_each = var.allowed_web_cidrs

    content {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # tfsec:ignore:AVD-AWS-0107 Intentional: this is a public web server, ports 80/443 must be reachable from the internet.
  dynamic "ingress" {
    for_each = var.allowed_web_cidrs

    content {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # tfsec:ignore:AVD-AWS-0104 Intentional: the instance needs unrestricted egress for OS packages and updates.
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-ec2-sg"
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  # data.aws_subnets returns IDs in a non-deterministic order, so sort
  # them to keep plans stable between runs.
  subnet_id = sort(data.aws_subnets.default.ids)[0]

  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id
  ]

  associate_public_ip_address = true
  monitoring                  = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = "terraform-${var.instance_type}"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
