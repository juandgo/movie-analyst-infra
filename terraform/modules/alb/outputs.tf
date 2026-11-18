output "dns_name" { value = aws_lb.this.dns_name }
output "lb_arn_suffix" { value = aws_lb.this.arn_suffix }
output "tg_arn_suffix" { value = aws_lb_target_group.this.arn_suffix }
