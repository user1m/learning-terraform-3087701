variable "ami_filter" {
  description = "name & owner filter for AMI"
  type = object({
    values = list(string)
    owners = list(string)
  })
  default = {
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
    owners = ["979382823631"] # Bitnami
  }
}

variable "env" {
  description = "Environment to deploy to"

  type = object({
    name          = string
    netwok_prefix = string
  })

  default = {
    name          = "dev"
    netwok_prefix = "10.0"
  }
}

variable "asg_min_size" {
  description = "Minimum size of the ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum size of the ASG"
  type        = number
  default     = 2
}

