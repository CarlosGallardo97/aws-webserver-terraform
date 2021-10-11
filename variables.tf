variable "region" {
  type = string
  default = "us-east-2"
}

variable "name" {
  type    = string
}

variable "vpc_name" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "availability_zone_names" {
  type    = list(string)
}

variable "private_subnets" {
  type    = list(string)
}

variable "public_subnets" {
  type    = list(string)
}

variable "database_subnets" {
  type    = list(string)
}

variable "aws_ami" {
  type    = string
}

variable "instance_type" {
  type    = string
}

variable "vpc_endpoints" {
  default = [
    "com.amazonaws.us-east-2.ssm",
    "com.amazonaws.us-east-2.ec2messages",
    "com.amazonaws.us-east-2.ec2",
    "com.amazonaws.us-east-2.ssmmessages"
  ]
}