output "alb_dns_name" {
  value = aws_lb.load-balancer.dns_name
  description = "The doman name of the load balancer"
}

output "asg_name" {
  value = aws_autoscaling_group.asg-example.name
  description = "The name of the Autoscaling Group"
}

output "EC2_instance_security_group_id" {
  value = aws_security_group.instance.id
  description = "The ID of the security Group attached to the EC2 instances"
}


output "alb_security_group_id" {
  value = aws_security_group.alb.id
  description = "The ID of the security group attached to load balancer"
}