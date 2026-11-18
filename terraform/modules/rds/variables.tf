variable "name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "sg_id" { type = string }
variable "instance_class" { type = string }
variable "engine_version" { type = string }
variable "db_name" { type = string }
variable "username" { type = string }

variable "password" {
  type      = string
  sensitive = true
}

variable "backup_retention" { type = number }
variable "deletion_protection" { type = bool }
variable "skip_final_snapshot" { type = bool }
