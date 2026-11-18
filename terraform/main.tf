provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "movie-analyst"
      Environment = local.env
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name         = "${local.env}-movie"
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  ssm_prefix   = "/${local.env}"
  db_app_user  = "movie_app"
  db_admin_usr = "dbadmin"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_key_pair" "this" {
  key_name   = "${local.name}-key"
  public_key = file(pathexpand(var.public_key_path))
}

# ---------------------------------------------------------------- network
module "network" {
  source = "./modules/network"

  name              = local.name
  vpc_cidr          = local.cfg.vpc_cidr
  azs               = local.azs
  nat_ami_id        = data.aws_ssm_parameter.al2023.value
  nat_instance_type = local.cfg.instance_type
  key_name          = aws_key_pair.this.key_name
}

module "security" {
  source = "./modules/security"

  name             = local.name
  vpc_id           = module.network.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

module "iam" {
  source = "./modules/iam"

  name       = local.name
  ssm_prefix = local.ssm_prefix
}

# ---------------------------------------------------------------- database
resource "random_password" "db_admin" {
  length  = 24
  special = false
}

resource "random_password" "db_app" {
  length  = 24
  special = false
}

module "rds" {
  source = "./modules/rds"

  name                = local.name
  subnet_ids          = module.network.db_subnet_ids
  sg_id               = module.security.db_sg_id
  instance_class      = local.cfg.db_instance_class
  engine_version      = var.db_engine_version
  db_name             = var.db_name
  username            = local.db_admin_usr
  password            = random_password.db_admin.result
  backup_retention    = local.cfg.db_backup_retention
  deletion_protection = local.cfg.db_deletion_protect
  skip_final_snapshot = local.cfg.db_skip_final_snap
}

# ---------------------------------------------------------------- compute
module "api" {
  source = "./modules/instance"

  name                = "${local.name}-api"
  role                = "api"
  ami_id              = data.aws_ssm_parameter.al2023.value
  instance_type       = local.cfg.instance_type
  subnet_id           = module.network.app_subnet_ids[0]
  security_group_ids  = [module.security.api_sg_id]
  key_name            = aws_key_pair.this.key_name
  instance_profile    = module.iam.app_profile_name
  associate_public_ip = false
  depends_on          = [module.network] # NAT route must exist before first boot
}

module "ui" {
  source = "./modules/instance"

  name                = "${local.name}-ui"
  role                = "ui"
  ami_id              = data.aws_ssm_parameter.al2023.value
  instance_type       = local.cfg.instance_type
  subnet_id           = module.network.public_subnet_ids[0]
  security_group_ids  = [module.security.ui_sg_id]
  key_name            = aws_key_pair.this.key_name
  instance_profile    = module.iam.app_profile_name
  associate_public_ip = true
}

module "bastion" {
  source = "./modules/instance"

  name                = "${local.name}-bastion"
  role                = "bastion"
  ami_id              = data.aws_ssm_parameter.al2023.value
  instance_type       = local.cfg.instance_type
  subnet_id           = module.network.mgmt_subnet_id
  security_group_ids  = [module.security.bastion_sg_id]
  key_name            = aws_key_pair.this.key_name
  instance_profile    = module.iam.bastion_profile_name
  associate_public_ip = true
  create_eip          = true
  user_data           = file("${path.module}/templates/bastion_user_data.sh")
}

# ---------------------------------------------------------------- load balancers
# Internal ALB: UI -> ALB -> API (mandatory "backend traffic goes through a load balancer")
module "alb_internal" {
  source = "./modules/alb"

  name                = "${local.name}-api"
  internal            = true
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.app_subnet_ids
  sg_id               = module.security.alb_internal_sg_id
  target_port         = 3000
  health_check_path   = "/" # API returns {"service_status":"Up"}
  target_instance_ids = [module.api.id]
}

# Public ALB: Internet -> ALB -> UI
module "alb_public" {
  source = "./modules/alb"

  name                = "${local.name}-ui"
  internal            = false
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  sg_id               = module.security.alb_public_sg_id
  target_port         = 3030
  health_check_path   = "/"
  target_instance_ids = [module.ui.id]
}

# ---------------------------------------------------------------- config handed to Ansible (SSM Parameter Store, free tier)
locals {
  ssm_params = {
    "db/host"           = { value = module.rds.address, secure = false }
    "db/name"           = { value = var.db_name, secure = false }
    "db/admin_user"     = { value = local.db_admin_usr, secure = false }
    "db/admin_password" = { value = random_password.db_admin.result, secure = true }
    "db/app_user"       = { value = local.db_app_user, secure = false }
    "db/app_password"   = { value = random_password.db_app.result, secure = true }
    "app/backend_url"   = { value = module.alb_internal.dns_name, secure = false }
  }
}

resource "aws_ssm_parameter" "this" {
  # for_each over the (non-sensitive) keys only; values are looked up below
  for_each = toset(keys(local.ssm_params))

  name  = "${local.ssm_prefix}/${each.key}"
  type  = local.ssm_params[each.key].secure ? "SecureString" : "String"
  value = local.ssm_params[each.key].value
}

# ---------------------------------------------------------------- monitoring
module "monitoring" {
  source = "./modules/monitoring"

  name               = local.name
  env                = local.env
  region             = var.region
  alert_email        = var.alert_email
  ui_instance_id     = module.ui.id
  api_instance_id    = module.api.id
  rds_identifier     = module.rds.identifier
  public_lb_suffix   = module.alb_public.lb_arn_suffix
  public_tg_suffix   = module.alb_public.tg_arn_suffix
  internal_lb_suffix = module.alb_internal.lb_arn_suffix
  internal_tg_suffix = module.alb_internal.tg_arn_suffix
}
