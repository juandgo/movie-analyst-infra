variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "nat_ami_id" { type = string }
variable "nat_instance_type" { type = string }
variable "key_name" { type = string }
