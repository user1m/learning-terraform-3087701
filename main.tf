data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

# data "aws_vpc" "default" {
#   default = true
# }

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev_env"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  # private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  # enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [ 
    # aws_security_group.web.id 
    # https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest?tab=outputs
    module.web_sg.security_group_id
  ]
  tags = {
    Name = "HelloWorld"
  }
}

module "web_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  name = "web_new_sec"
  
  # vpc_id      = data.aws_vpc.default.id
  vpc_id      = module.vpc.public_subnets[0]

  # https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf
  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  # https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest?tab=inputs
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group" "web" {
  name        = "web"
  description = "Allow HTTP and HTTPS inbound traffic"
  vpc_id      = data.aws_vpc.default.id  
}

resource "aws_security_group_rule" "web_http_in" {
  type                     = "ingress"
  description              = "Inbound traffic from HTTP"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]

  security_group_id = aws_security_group.web.id
}

resource "aws_security_group_rule" "web_https_in" {
  type                     = "ingress"
  description              = "Inbound traffic from HTTPs"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]

  security_group_id = aws_security_group.web.id
}

resource "aws_security_group_rule" "web_out" {
  type                     = "egress"
  description              = "All outbound traffic by default"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks              = ["0.0.0.0/0"]

  security_group_id = aws_security_group.web.id
}