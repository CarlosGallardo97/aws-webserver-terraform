provider "aws" {
  region = var.region
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

################################################################################
# Security Groups Module
################################################################################

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

resource "aws_security_group" "endpoint_sg" {
  name        = "endpoint-sg"
  description = "Security Group for VPC Endpoints"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################################################################
# IAM Roles
################################################################################

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = var.name

  # Sometimes good sleep is required to have some IAM resources created before they can be used
  #provisioner "local-exec" {
  #  command = "sleep 10"
  #}
  provisioner "local-exec" {
    command = "start-sleep 10"
    interpreter = ["PowerShell", "-Command"]
  }
}

module "iam_assumable_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services = [
    "ec2.amazonaws.com"
  ]
  create_role             = true
  create_instance_profile = true
  role_name         = "ssm-rd-role"
  role_requires_mfa = false
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  ]
  number_of_custom_role_policy_arns = 3
}

################################################################################
# Application Loadbalancer Module
################################################################################

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"
  name = var.name
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
      name             = var.name
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
# Autoscaling groups
################################################################################

# Launch template webserver
module "lt_webserver" {
  source = "terraform-aws-modules/autoscaling/aws"
  # Autoscaling group
  name = "lt_webserver-${var.name}"
  vpc_zone_identifier = module.vpc.private_subnets
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn
  # Launch template
  use_lt    = true
  create_lt = true
  image_id      = var.aws_ami
  instance_type = var.instance_type
  security_groups = [module.frontend_asg_sg.security_group_id]
  iam_instance_profile_arn = module.iam_assumable_role.iam_instance_profile_arn
  target_group_arns = module.alb.target_group_arns
}

# Launch template databases
module "lt_databases" {
  source = "terraform-aws-modules/autoscaling/aws"
  # Autoscaling group
  name = "lt_databases-${var.name}"
  vpc_zone_identifier = module.vpc.database_subnets
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn
  # Launch template
  use_lt    = true
  create_lt = true
  image_id      = var.aws_ami
  instance_type = var.instance_type
  security_groups = [module.backend_asg_sg.security_group_id]
  iam_instance_profile_arn = module.iam_assumable_role.iam_instance_profile_arn
}

################################################################################
# SNS Topic, Autoscaling policies and Cloudwatch metrics
################################################################################

resource "aws_sns_topic" "rd_topic" {
  name = "rd_topic"
}

resource "aws_sns_topic_subscription" "rd_topic_sns_target" {
  topic_arn = aws_sns_topic.rd_topic.arn
  protocol  = "email"
  endpoint  = "carlos_xavier97@hotmail.com"
}

resource "aws_autoscaling_policy" "scale-in" {
  name                   = "scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = module.lt_webserver.autoscaling_group_name
}

resource "aws_autoscaling_policy" "scale-out" {
  name                   = "scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = module.lt_webserver.autoscaling_group_name
}

resource "aws_cloudwatch_metric_alarm" "scale-out-alarm" {
  alarm_name          = "rd-scale-out"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "50"
  dimensions = {
    AutoScalingGroupName = module.lt_webserver.autoscaling_group_name
  }

  alarm_description = "This metric monitors asg cpu utilization"
  alarm_actions     = [aws_sns_topic.rd_topic.arn, aws_autoscaling_policy.scale-out.arn]
}

resource "aws_cloudwatch_metric_alarm" "scale-in-alarm" {
  alarm_name          = "rd-scale-in"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "15"
  dimensions = {
    AutoScalingGroupName = module.lt_webserver.autoscaling_group_name
  }
  alarm_description = "This metric monitors asg cpu utilization"
  alarm_actions     = [aws_sns_topic.rd_topic.arn, aws_autoscaling_policy.scale-in.arn]
}

################################################################################
# VPC Endpoints
################################################################################

resource "aws_vpc_endpoint" "endpoints" {
  count             = length(var.vpc_endpoints)
  vpc_id            = module.vpc.vpc_id
  service_name      = var.vpc_endpoints[count.index]
  vpc_endpoint_type = "Interface"
  private_dns_enabled = "true"
  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]
  subnet_ids = module.vpc.private_subnets
}

