region = "us-east-2"

vpc_name = "rd-vpc"

vpc_cidr_block = "192.168.0.0/16"

availability_zone_names = [
  "us-east-2a",
  "us-east-2b",
]

private_subnets = [
  "192.168.16.0/24",
  "192.168.24.0/24"
]

public_subnets = [
  "192.168.1.0/24",
  "192.168.8.0/24"
]

database_subnets = [
  "192.168.32.0/24",
  "192.168.40.0/24"
]

aws_ami = "ubuntu/images/ubuntu-*-*-amd64-server-*"