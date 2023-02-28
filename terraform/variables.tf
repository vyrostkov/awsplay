variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "image" {
  type    = string
  default = "286972415665.dkr.ecr.eu-west-2.amazonaws.com/awsplay:3850595d86ad778b95a8cfbc908aeba217461670"
}

variable "route53_zone" {
  type    = string
  default = "Z2Z0QPGK7E01E9"
}

variable "route53_domain" {
  type    = string
  default = "awsplay.diman8.net"
}

variable "acm_cert_arn" {
  type    = string
  default = "arn:aws:acm:eu-west-1:286972415665:certificate/ee4e9dc1-e2e3-490f-8968-a51164a22bbe"
}

