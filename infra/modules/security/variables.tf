variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for internal VPC communication and DNS."
  type        = string
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
