output "vpc_id" {
  description = "Development VPC ID."
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "Development public subnet ID."
  value       = module.networking.public_subnet_id
}

output "security_group_id" {
  description = "EC2 security group ID."
  value       = module.security.security_group_id
}

output "ec2_instance_id" {
  description = "Development EC2 instance ID."
  value       = module.compute.instance_id
}

output "ec2_public_ip" {
  description = "Development EC2 public IP."
  value       = module.compute.public_ip
}

output "ec2_private_ip" {
  description = "Development EC2 private IP."
  value       = module.compute.private_ip
}

output "ec2_ami_id" {
  description = "Ubuntu AMI used by EC2."
  value       = module.compute.ami_id
}
