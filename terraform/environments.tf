# Per-environment settings live in code, keyed by workspace name, so you can never
# apply "prod" settings to the "qa" workspace by picking the wrong -var-file.
locals {
  environments = {
    qa = {
      vpc_cidr            = "10.10.0.0/16"
      instance_type       = "t3.micro"
      db_instance_class   = "db.t3.micro"
      db_backup_retention = 1
      db_deletion_protect = false
      db_skip_final_snap  = true
    }
    prod = {
      vpc_cidr            = "10.20.0.0/16"
      instance_type       = "t3.micro"
      db_instance_class   = "db.t3.micro"
      db_backup_retention = 1 # free-tier accounts cap backups; raise if your account allows
      db_deletion_protect = true
      db_skip_final_snap  = false
    }
  }

  env = terraform.workspace
  cfg = local.environments[local.env]
}

check "workspace_is_valid" {
  assert {
    condition     = contains(keys(local.environments), terraform.workspace)
    error_message = "Use workspace 'qa' or 'prod' (terraform workspace new qa)."
  }
}
