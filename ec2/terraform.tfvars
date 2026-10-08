aws_region    = "us-east-1"
instance_type = "t3.small"

ami_id = "ami-0b6d9d3d33ba97d99"

# Optional, and only useful once SSH is opened below: the key pair must
# already exist in AWS_REGION or RunInstances fails with InvalidKeyPair.
# key_name = "my-key-pair"

# SSH stays closed until you allow your own IP, e.g. ["203.0.113.10/32"]
allowed_ssh_cidrs = []
allowed_web_cidrs = ["0.0.0.0/0"]
