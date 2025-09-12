output "manager_public_ip" {
  description = "Public IP of the Swarm manager"
  value       = aws_instance.manager.public_ip
}

output "ssh_command_manager" {
  description = "SSH command to connect to manager"
  value       = "ssh -i ~/.ssh/docker-swarm-key.pem ec2-user@${aws_instance.manager.public_ip}"
}

output "visualizer_url" {
  description = "URL to Docker Swarm Visualizer via Load Balancer"
  value       = "http://${module.networking.alb_dns_name}:8080"
}

output "web_service_url" {
  description = "URL to web service (nginx) via Load Balancer"
  value       = "http://${module.networking.alb_dns_name}"
}

output "fastapi_url" {
  description = "URL to FastAPI application via Load Balancer"
  value       = "http://${module.networking.alb_dns_name}:8001"
}

output "load_balancer_dns" {
  description = "DNS name of the Load Balancer"
  value       = module.networking.alb_dns_name
}

output "docker_node_ls_command" {
  description = "Command to check swarm nodes"
  value       = "ssh -i ~/.ssh/docker-swarm-key.pem ec2-user@${aws_instance.manager.public_ip} 'docker node ls'"
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.worker_asg.name
}

output "autoscaling_group_info" {
  description = "Auto Scaling Group information"
  value = {
    name             = aws_autoscaling_group.worker_asg.name
    min_size         = aws_autoscaling_group.worker_asg.min_size
    max_size         = aws_autoscaling_group.worker_asg.max_size
    desired_capacity = aws_autoscaling_group.worker_asg.desired_capacity
  }
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for image storage"
  value       = aws_s3_bucket.image_uploads.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for posts"
  value       = aws_dynamodb_table.posts.name
}

# Networking module outputs
output "networking" {
  description = "Networking module outputs"
  value = {
    vpc_id            = module.networking.vpc_id
    alb_dns_name      = module.networking.alb_dns_name
    target_group_arns = module.networking.target_group_arns
    security_group_id = module.networking.security_group_id
  }
}