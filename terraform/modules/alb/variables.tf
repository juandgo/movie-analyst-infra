variable "name" { type = string }
variable "internal" { type = bool }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "sg_id" { type = string }
variable "target_port" { type = number }
variable "health_check_path" { type = string }
variable "target_instance_ids" { type = list(string) }
