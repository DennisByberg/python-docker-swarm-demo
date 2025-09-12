output "manager_instance_id" {
  description = "ID of the manager EC2 instance"
  value       = aws_instance.manager.id
}

output "manager_public_ip" {
  description = "Public IP address of the manager instance"
  value       = aws_instance.manager.public_ip
}

output "manager_private_ip" {
  description = "Private IP address of the manager instance"
  value       = aws_instance.manager.private_ip
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.worker_asg.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.worker_asg.arn
}

output "autoscaling_group_info" {
  description = "Auto Scaling Group configuration information"
  value = {
    name             = aws_autoscaling_group.worker_asg.name
    min_size         = aws_autoscaling_group.worker_asg.min_size
    max_size         = aws_autoscaling_group.worker_asg.max_size
    desired_capacity = aws_autoscaling_group.worker_asg.desired_capacity
  }
}

output "launch_template_id" {
  description = "ID of the worker launch template"
  value       = aws_launch_template.worker_template.id
}

output "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_policy_arn" {
  description = "ARN of the scale down policy"
  value       = aws_autoscaling_policy.scale_down.arn
}

output "cpu_high_alarm_arn" {
  description = "ARN of the CPU high utilization alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

output "cpu_low_alarm_arn" {
  description = "ARN of the CPU low utilization alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_low.arn
}