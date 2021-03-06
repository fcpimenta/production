# Security Group Terraform module

## Usage

```hcl

module "security_group" {
  source      = "../../modules/security_groups"
  name        = "web"
  vpc_id      = "vpc-000"
  description = "Allow Http"

  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  # With predefined rules
  ingress_rules = [
    "http-80-tcp",
    "https-443-tcp",
    "all-icmp"
  ]

  # With custom rules
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH only from that cidr"
      cidr_blocks = "10.0.0.0/16"
    },
  ]

  egress_rules = ["all-all"]
}
```
### Environment variables and credentials:


1. TF_VAR_AWS_DEFAULT_REGION

Credentials:
   
    $ aws configure

## Tests

```shell
 $ make test
```
