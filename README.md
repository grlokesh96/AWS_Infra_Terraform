# AWS_Infra_Terraform

Terraform configuration and CI/CD pipeline that provisions an Ubuntu EC2 instance
in AWS, with a gated plan/apply workflow and a full set of security and
lint checks on every push and pull request.

## Repository layout

```text
.
├── .github/
│   └── workflows/
│       └── terraform.yml   # CI/CD pipeline (init, lint, scan, plan, approve, apply)
└── ec2/
    ├── main.tf             # VPC/subnet lookup, security group, EC2 instance
    ├── provider.tf         # Terraform + AWS provider requirements
    ├── variables.tf        # Input variables (with validation)
    ├── outputs.tf          # instance_id / public_ip / private_ip / instance_type
    └── terraform.tfvars    # Non-sensitive default values used by CI
```

## What gets provisioned

| Resource | Notes |
| --- | --- |
| `aws_security_group.ec2_sg` | SSH disabled by default, HTTP/HTTPS driven by `allowed_web_cidrs`, unrestricted egress |
| `aws_instance.app_server` | `t3.medium`, 25 GB encrypted gp3 root volume, IMDSv2 required, detailed monitoring on |
| Data sources | Default VPC and one of its subnets (sorted for stable plans) |

## Prerequisites

- Terraform >= 1.6 (CI pins 1.9.8)
- AWS credentials with permission to manage EC2/EC2-Classic networking
- (Optional) An [Infracost](https://www.infracost.io/) API key for cost estimates

## Usage

```bash
cd ec2
terraform init
terraform plan
terraform apply
```

### Variables

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `aws_region` | `string` | `us-east-1` | AWS region to deploy into |
| `instance_type` | `string` | `t3.medium` | EC2 instance type |
| `ami_id` | `string` | – | AMI ID for the target region (required) |
| `key_name` | `string` | `null` | Existing EC2 key pair name (optional) |
| `allowed_ssh_cidrs` | `list(string)` | `[]` | CIDRs allowed on port 22. Empty = SSH closed |
| `allowed_web_cidrs` | `list(string)` | `["0.0.0.0/0"]` | CIDRs allowed on ports 80/443 |

### Enabling SSH

SSH is closed by default. To allow your own IP, open the port and point the
instance at a key pair that already exists in the region:

```bash
aws ec2 create-key-pair --key-name my-key-pair \
  --query 'KeyMaterial' --output text > ~/.ssh/my-key-pair.pem
chmod 600 ~/.ssh/my-key-pair.pem
```

```hcl
# ec2/terraform.tfvars
allowed_ssh_cidrs = ["203.0.113.10/32"]
key_name          = "my-key-pair"
```

Leaving `key_name` unset launches the instance without a key pair. Setting it
to a pair that does not exist in `aws_region` makes the apply fail with
`InvalidKeyPair.NotFound`, which is why it is optional.

Any `0.0.0.0/0` entry will be reported by tfsec, which is intentional.

## CI/CD pipeline

Triggered on pushes to `main` and `feature/**`, and on pull requests to `main`.
The Terraform root module used by the pipeline is `./ec2`.

| Job | Purpose |
| --- | --- |
| `config-check` | Detects optional secrets (skips Infracost when no API key) |
| `terraform-init-validate` | `terraform init -backend=false`, `fmt -check`, `validate` |
| `tflint` | Terraform linting |
| `tfsec` | Terraform security scanning |
| `gitleaks` | Secret scanning over the full git history |
| `terrascan` | IaC policy scanning |
| `super-linter` | Terraform / YAML / JSON linting |
| `terraform-plan` | Real `terraform plan`, uploaded as the `terraform-plan` artifact |
| `infracost` | Cost estimate (only when `INFRACOST_API_KEY` is configured) |
| `terraform-approval` | Manual gate via the `production` environment |
| `terraform-apply` | Applies the exact plan produced by `terraform-plan` |

Deployments are restricted to pushes on `main`: pull requests and feature
branches run every check and produce a plan, but never reach approval/apply.

### Required GitHub configuration

Repository secrets:

| Secret | Required | Used by |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | yes | `terraform-plan`, `terraform-apply` |
| `AWS_SECRET_ACCESS_KEY` | yes | `terraform-plan`, `terraform-apply` |
| `INFRACOST_API_KEY` | no | `infracost` (job is skipped when absent) |

An environment named `production` is referenced by the approval and apply jobs.
Add required reviewers to that environment in
*Settings → Environments* to enforce a manual approval before every deploy.

## Security notes

- **SSH is closed by default**; opt in with `allowed_ssh_cidrs`.
- **IMDSv2 is required** (`http_tokens = "required"`) and detailed monitoring is on.
- **Root volume is encrypted** (gp3, 25 GB).
- tfsec exceptions are explicit and documented in `main.tf`: ports 80/443 are
  open to the internet on purpose (public web server) and egress is unrestricted
  so the instance can install packages.

## Known limitations

State is **local** (no remote backend), which means each pipeline run starts
from an empty state file:

- the plan/apply pair is internally consistent within a single run, but
- a second run will try to create resources that already exist and will fail at
  `terraform apply`.

For anything beyond a demo, configure an S3 backend with state locking:

```hcl
# ec2/provider.tf
terraform {
  backend "s3" {
    bucket         = "your-tfstate-bucket"
    key            = "ec2/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "your-tfstate-lock"
    encrypt        = true
  }
}
```
