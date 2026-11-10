output "instance_profile_name" {
  description = "Name of the EC2 IAM instance profile."
  value       = aws_iam_instance_profile.ec2.name
}

output "instance_profile_arn" {
  description = "ARN of the EC2 IAM instance profile."
  value       = aws_iam_instance_profile.ec2.arn
}

output "iam_role_name" {
  description = "Name of the EC2 IAM role."
  value       = aws_iam_role.ec2.name
}
