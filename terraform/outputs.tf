# Manager instance outputs
output "manager_public_ip" {
  description = "Public IP of the Swarm manager"
  value       = module.compute.manager_public_ip
}

output "ssh_command_manager" {
  description = "SSH command to connect to manager"
  value       = "ssh -i ${module.ssh.private_key_path} ec2-user@${module.compute.manager_public_ip}"
}

# Service URLs via Load Balancer
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

# Docker commands
output "docker_node_ls_command" {
  description = "Command to check swarm nodes"
  value       = "ssh -i ${module.ssh.private_key_path} ec2-user@${module.compute.manager_public_ip} 'docker node ls'"
}

# Auto Scaling Group information
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.autoscaling_group_name
}

output "autoscaling_group_info" {
  description = "Auto Scaling Group information"
  value       = module.compute.autoscaling_group_info
}

# Storage outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for image storage"
  value       = module.storage.s3_bucket_id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for posts"
  value       = module.storage.dynamodb_table_name
}

# Module outputs for advanced users
output "ssh_info" {
  description = "SSH module outputs"
  value = {
    key_name         = module.ssh.key_name
    private_key_path = module.ssh.private_key_path
  }
}

output "networking_info" {
  description = "Networking module outputs"
  value = {
    vpc_id            = module.networking.vpc_id
    alb_dns_name      = module.networking.alb_dns_name
    target_group_arns = module.networking.target_group_arns
    security_group_id = module.networking.security_group_id
  }
}

output "storage_info" {
  description = "Storage module outputs"
  value = {
    s3_bucket_arn      = module.storage.s3_bucket_arn
    dynamodb_table_arn = module.storage.dynamodb_table_arn
  }
}