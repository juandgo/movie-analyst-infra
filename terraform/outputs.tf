output "app_url" {
  description = "Public URL of the application."
  value       = "http://${module.alb_public.dns_name}"
}

output "bastion_public_ip" {
  value = module.bastion.public_ip
}

output "ssh_to_bastion" {
  description = "Use -A so your key is forwarded and Ansible can reach the private instances."
  value       = "ssh -A ec2-user@${module.bastion.public_ip}"
}

output "internal_alb_dns" {
  value = module.alb_internal.dns_name
}

output "rds_endpoint" {
  value = module.rds.address
}

output "dashboard_url" {
  value = module.monitoring.dashboard_url
}
