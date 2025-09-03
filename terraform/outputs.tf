output "manager_ip" {
  description = "Public IP address of the manager node"
  value       = aws_instance.manager.public_ip
}

output "worker_ips" {
  description = "Public IP addresses of worker nodes"
  value       = aws_instance.workers[*].public_ip
}

output "manager_private_ip" {
  description = "Private IP address of the manager node"
  value       = aws_instance.manager.private_ip
}

output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = aws_instance.workers[*].private_ip
}

output "security_group_id" {
  description = "ID of the Docker Swarm security group"
  value       = aws_security_group.docker_swarm.id
}