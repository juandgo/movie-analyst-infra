variable "name" { type = string }
variable "role" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "subnet_id" { type = string }
variable "security_group_ids" { type = list(string) }
variable "key_name" { type = string }
variable "instance_profile" { type = string }
variable "associate_public_ip" { type = bool }

variable "create_eip" {
  type    = bool
  default = false
}

variable "user_data" {
  type    = string
  default = null
}
