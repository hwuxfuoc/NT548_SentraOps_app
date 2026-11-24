variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  description = "Tên key pair trong AWS Console (không phải tên file .pem)"
  type        = string
}

variable "project_name" {
  type    = string
  default = "sentraops"
}
