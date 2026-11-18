output "bastion_sg_id" { value = aws_security_group.bastion.id }
output "alb_public_sg_id" { value = aws_security_group.alb_public.id }
output "ui_sg_id" { value = aws_security_group.ui.id }
output "alb_internal_sg_id" { value = aws_security_group.alb_internal.id }
output "api_sg_id" { value = aws_security_group.api.id }
output "db_sg_id" { value = aws_security_group.db.id }
