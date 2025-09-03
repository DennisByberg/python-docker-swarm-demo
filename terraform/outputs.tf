output "manager_public_ip" {
  description = "Public IP of the Swarm manager"
  value       = aws_instance.manager.public_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = aws_instance.workers[*].public_ip
}

output "ssh_command_manager" {
  description = "SSH command to connect to manager"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.manager.public_ip}"
}

output "visualizer_url" {
  description = "URL to Docker Swarm Visualizer"
  value       = "http://${aws_instance.manager.public_ip}:8080"
}

output "web_service_url" {
  description = "URL to web service (nginx)"
  value       = "http://${aws_instance.manager.public_ip}"
}

output "docker_node_ls_command" {
  description = "Command to check swarm nodes"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.manager.public_ip} 'docker node ls'"
}