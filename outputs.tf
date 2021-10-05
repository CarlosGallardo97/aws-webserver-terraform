# VPC
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

# CIDR blocks
output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# Subnets
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# NAT gateways
output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_public_ips
}

# AZs
output "azs" {
  description = "A list of availability zones spefified as argument to this module"
  value       = module.vpc.azs
}

################################################################################
# Default ASG
################################################################################

# Launch template
output "lt_webserver_launch_template_id" {
  description = "The ID of the launch template"
  value       = module.lt_webserver.launch_template_id
}

output "lt_webserver_launch_template_arn" {
  description = "The ARN of the launch template"
  value       = module.lt_webserver.launch_template_arn
}

output "lt_webserver_launch_template_latest_version" {
  description = "The latest version of the launch template"
  value       = module.lt_webserver.launch_template_latest_version
}

output "lt_webserver_autoscaling_group_id" {
  description = "The autoscaling group id"
  value       = module.lt_webserver.autoscaling_group_id
}

output "lt_webserver_autoscaling_group_name" {
  description = "The autoscaling group name"
  value       = module.lt_webserver.autoscaling_group_name
}

output "lt_webserver_autoscaling_group_arn" {
  description = "The ARN for this AutoScaling Group"
  value       = module.lt_webserver.autoscaling_group_arn
}

output "lt_webserver_autoscaling_group_min_size" {
  description = "The minimum size of the autoscale group"
  value       = module.lt_webserver.autoscaling_group_min_size
}

output "lt_webserver_autoscaling_group_max_size" {
  description = "The maximum size of the autoscale group"
  value       = module.lt_webserver.autoscaling_group_max_size
}

output "lt_webserver_autoscaling_group_desired_capacity" {
  description = "The number of Amazon EC2 instances that should be running in the group"
  value       = module.lt_webserver.autoscaling_group_desired_capacity
}

output "lt_webserver_autoscaling_group_default_cooldown" {
  description = "Time between a scaling activity and the succeeding scaling activity"
  value       = module.lt_webserver.autoscaling_group_default_cooldown
}

output "lt_webserver_autoscaling_group_health_check_grace_period" {
  description = "Time after instance comes into service before checking health"
  value       = module.lt_webserver.autoscaling_group_health_check_grace_period
}

output "lt_webserver_autoscaling_group_health_check_type" {
  description = "EC2 or ELB. Controls how health checking is done"
  value       = module.lt_webserver.autoscaling_group_health_check_type
}

output "lt_webserver_autoscaling_group_availability_zones" {
  description = "The availability zones of the autoscale group"
  value       = module.lt_webserver.autoscaling_group_availability_zones
}

output "lt_webserver_autoscaling_group_vpc_zone_identifier" {
  description = "The VPC zone identifier"
  value       = module.lt_webserver.autoscaling_group_vpc_zone_identifier
}

output "lt_webserver_autoscaling_group_load_balancers" {
  description = "The load balancer names associated with the autoscaling group"
  value       = module.lt_webserver.autoscaling_group_load_balancers
}

output "lt_webserver_autoscaling_group_target_group_arns" {
  description = "List of Target Group ARNs that apply to this AutoScaling Group"
  value       = module.lt_webserver.autoscaling_group_target_group_arns
}

