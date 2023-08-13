# output "instance_ami" {
#  value = aws_instance.web.ami
# }

# output "instance_arn" {
#  value = aws_instance.web.arn
# }

output "web_url" {
    value = module.web_alb.lb_dns_name
}