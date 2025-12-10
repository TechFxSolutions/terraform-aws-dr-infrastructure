# Compute Module Outputs

output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.main.id
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

output "web_target_group_arn" {
  description = "ARN of the web tier target group"
  value       = aws_lb_target_group.web.arn
}

output "web_asg_name" {
  description = "Name of the web tier Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "web_asg_arn" {
  description = "ARN of the web tier Auto Scaling Group"
  value       = aws_autoscaling_group.web.arn
}

output "app_asg_name" {
  description = "Name of the application tier Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "app_asg_arn" {
  description = "ARN of the application tier Auto Scaling Group"
  value       = aws_autoscaling_group.app.arn
}

output "web_scale_up_policy_arn" {
  description = "ARN of the web tier scale up policy"
  value       = aws_autoscaling_policy.web_scale_up.arn
}

output "web_scale_down_policy_arn" {
  description = "ARN of the web tier scale down policy"
  value       = aws_autoscaling_policy.web_scale_down.arn
}

output "app_scale_up_policy_arn" {
  description = "ARN of the application tier scale up policy"
  value       = aws_autoscaling_policy.app_scale_up.arn
}

output "app_scale_down_policy_arn" {
  description = "ARN of the application tier scale down policy"
  value       = aws_autoscaling_policy.app_scale_down.arn
}

output "bastion_instance_id" {
  description = "ID of the bastion host instance"
  value       = var.enable_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = var.enable_bastion ? aws_eip.bastion[0].public_ip : null
}
