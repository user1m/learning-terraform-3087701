data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = var.ami_filter.values
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = var.ami_filter.owners
}

# data "aws_vpc" "default" {
#   default = true
# }

module "web_vpc" {
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.env.name}_vpc"
  cidr = "${var.env.network_prefix}.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["${var.env.network_prefix}.1.0/24", "${var.env.network_prefix}.2.0/24", "${var.env.network_prefix}.3.0/24"]
  public_subnets  = ["${var.env.network_prefix}.101.0/24", "${var.env.network_prefix}.102.0/24", "${var.env.network_prefix}.103.0/24"]

  enable_nat_gateway = true
  # enable_vpn_gateway = true

  # single_nat_gateway = false
  # one_nat_gateway_per_az = true

  tags = {
    Terraform = "true"
    Environment = var.env.name
  }
}

# resource "aws_instance" "web" {
#   ami           = data.aws_ami.app_ami.id
#   instance_type = var.instance_type
#   vpc_security_group_ids = [ 
#     # aws_security_group.web.id 
#     # https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest?tab=outputs
#     module.web_sg.security_group_id
#   ]
#   tags = {
#     Name = "HelloWorld"
#   }
# }

module "web_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  name = "${var.env.name}-web_new_sec"
  
  # vpc_id      = data.aws_vpc.default.id
  # vpc_id      = module.web_vpc.public_subnets[0]
  vpc_id = module.web_vpc.vpc_id

  # https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf
  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  # https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest?tab=inputs
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group" "web" {
  name        = "${var.env.name}-web"
  description = "Allow HTTP and HTTPS inbound traffic"
  # vpc_id      = data.aws_vpc.default.id  
  vpc_id = module.web_vpc.vpc_id
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

module "web_alb" {
  # https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/latest
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "${var.env.name}-alb"

  load_balancer_type = "application"

  vpc_id             = module.web_vpc.vpc_id
  subnets            = module.web_vpc.public_subnets
  security_groups    = [ module.web_sg.security_group_id ]

  # access_logs = {
  #   bucket = "my-alb-logs"
  # }

  target_groups = [
    {
      name_prefix      = "web-${var.env.name}-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      # targets = {
      #   # my_target = {
      #   #   target_id = aws_instance.web.id
      #   #   port = 80
      #   # }
      #   # my_other_target = {
      #   #   target_id = "i-a1b2c3d4e5f6g7h8i"
      #   #   port = 8080
      #   # }
      # }
    }
  ]

  # https_listeners = [
  #   {
  #     port               = 443
  #     protocol           = "HTTPS"
  #     certificate_arn    = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
  #     target_group_index = 0
  #   }
  # ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = var.env.name
  }
}

module "autoscaling" {
  # https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws/latest
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.10.0"
  # insert the 1 required variable here
  name = "web-auto-scaling"

  min_size = var.asg_min_size
  max_size = var.asg_max_size

  vpc_zone_identifier = module.web_vpc.public_subnets
  target_group_arns = module.web_alb.target_group_arns
  security_groups = module.web_vpc.vpc_id

  image_id = data.aws_ami.app_ami.id
  instance_type = var.instance_type

}