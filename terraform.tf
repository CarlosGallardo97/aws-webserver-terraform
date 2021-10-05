provider "aws" {
  region = var.region
}

locals {
  name   = "example-asg"
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.vpc_name
  cidr = var.vpc_cidr_block

  azs              = var.availability_zone_names
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  database_subnets = var.database_subnets

  enable_ipv6 = true

  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  vpc_tags = {
    Terraform = "true"
  }
}

module "frontend_asg_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "frontend-asg-sg"
  description = "A security group frontend layer"
  vpc_id      = module.vpc.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    },
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 2

  egress_rules = ["all-all"]

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

module "backend_asg_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "backend-asg-sg"
  description = "A security group backend layer"
  vpc_id      = module.vpc.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.frontend_asg_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

data "aws_ami" "ubuntu_server" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name = "name"

    values = [
      "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
    ]
  }
}

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = local.name

  # Sometimes good sleep is required to have some IAM resources created before they can be used
  #provisioner "local-exec" {
  #  command = "sleep 10"
  #}
  provisioner "local-exec" {
    command = "start-sleep 10"
    interpreter = ["PowerShell", "-Command"]
  }
}

resource "aws_iam_instance_profile" "ssm" {
  name = "complete-${local.name}"
  role = aws_iam_role.ssm.name
  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

resource "aws_iam_role" "ssm" {
  name = "complete-${local.name}"
  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  assume_role_policy = <<-EOT
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOT
}

module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "alb-sg"
  description = "A security group for alb"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "http-80-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "https-443-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_rules = ["all-all"]

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = local.name

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_sg.security_group_id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name             = local.name
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    },
  ]

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}


################################################################################
# Default
################################################################################

# Launch template webserver
module "lt_webserver" {
  source = "terraform-aws-modules/autoscaling/aws"

  # Autoscaling group
  name = "lt_webserver-${local.name}"

  vpc_zone_identifier = module.vpc.private_subnets
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn

  # Launch template
  use_lt    = true
  create_lt = true

  image_id      = data.aws_ami.ubuntu_server.id
  instance_type = "t2.micro"

  security_groups = [module.frontend_asg_sg.security_group_id]

  iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn

  target_group_arns = module.alb.target_group_arns
}

# Launch template webserver
module "lt_databases" {
  source = "terraform-aws-modules/autoscaling/aws"

  # Autoscaling group
  name = "lt_databases-${local.name}"

  vpc_zone_identifier = module.vpc.database_subnets
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn

  # Launch template
  use_lt    = true
  create_lt = true

  image_id      = data.aws_ami.ubuntu_server.id
  instance_type = "t2.micro"

  security_groups = [module.backend_asg_sg.security_group_id]

  iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn

}

/* module "ssm" {
  source                    = "bridgecrewio/session-manager/aws"
  version                   = "0.2.0"
  bucket_name               = "rd-bucket-2709"
  access_log_bucket_name    = "rd-bucket-2709-al"
  vpc_id                    = module.vpc.vpc_id
  tags                      = {
                                Function = "ssm"
                              }
  enable_log_to_s3          = true
  enable_log_to_cloudwatch  = true
  vpc_endpoints_enabled     = true
}  */