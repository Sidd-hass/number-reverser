variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.medium"
}

variable "subnet_id" {
  description = "Public subnet ID where EC2 will be deployed."
  type        = string
}

variable "security_group_id" {
  description = "Security group ID attached to EC2."
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile attached to EC2."
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 30
    error_message = "The root volume must be at least 30 GiB."
  }
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
