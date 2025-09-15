output "security_group_id" {
  description = "ID of the Docker Swarm security group"
  value       = aws_security_group.docker_swarm.id
}

output "subnet_ids" {
  description = "List of subnet IDs in the default VPC"
  value       = data.aws_subnets.default.ids
}

output "target_group_arns" {
  description = "ARNs of all target groups"
  value = {
    nginx      = aws_lb_target_group.nginx.arn
    visualizer = aws_lb_target_group.visualizer.arn
    fastapi    = aws_lb_target_group.fastapi.arn
  }
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}