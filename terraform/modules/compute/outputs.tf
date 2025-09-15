output "manager_public_ip" {
  description = "Public IP of the manager instance"
  value       = aws_instance.manager.public_ip
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.worker_asg.name
}