output "vpc_id" {
  description = "ID of the default VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "List of subnet IDs in the default VPC"
  value       = data.aws_subnets.default.ids
}

output "security_group_id" {
  description = "ID of the Docker Swarm security group"
  value       = aws_security_group.docker_swarm.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arns" {
  description = "ARNs of all target groups"
  value = {
    nginx      = aws_lb_target_group.nginx.arn
    visualizer = aws_lb_target_group.visualizer.arn
    fastapi    = aws_lb_target_group.fastapi.arn
  }
}

output "target_group_names" {
  description = "Names of all target groups"
  value = {
    nginx      = aws_lb_target_group.nginx.name
    visualizer = aws_lb_target_group.visualizer.name
    fastapi    = aws_lb_target_group.fastapi.name
  }
}