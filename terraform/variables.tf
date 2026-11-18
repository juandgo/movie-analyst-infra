variable "region" {
  type    = string
  default = "us-east-2"
}

variable "allowed_ssh_cidr" {
  description = "Your public IP in CIDR form, e.g. 190.1.2.3/32. Only this range can SSH to the bastion."
  type        = string
}

variable "public_key_path" {
  description = "Path to the SSH public key installed on all instances."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "alert_email" {
  description = "Email that receives CloudWatch alarm notifications (you must confirm the SNS subscription)."
  type        = string
}

variable "db_name" {
  type    = string
  default = "movie_db"
}

variable "db_engine_version" {
  type    = string
  default = "8.4"
}
