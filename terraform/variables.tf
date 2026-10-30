variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "EC2 key pair name (must exist in the region)"
  type        = string
  default     = "key"
}

variable "project_name" {
  description = "Project name used in resource tags and names"
  type        = string
  default     = "sentraops"
}
