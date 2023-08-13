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

data "aws_vpc" "defaulf" {
  default = true
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [ aws_security_group.web.id ]
  tags = {
    Name = "HelloWorld"
  }
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