# Least-privilege chain: Internet -> ALB(80) -> UI(3030) -> internal ALB(80) -> API(3000) -> RDS(3306)
# SSH only from the bastion; the bastion only from your IP.

resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "SSH from the admin IP only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_public" {
  name        = "${var.name}-alb-public-sg"
  description = "Public ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ui" {
  name        = "${var.name}-ui-sg"
  description = "Front-end instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "App port from the public ALB"
    from_port   = 3030
    to_port     = 3030
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.alb_public.id]
  }

  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_internal" {
  name        = "${var.name}-alb-internal-sg"
  description = "Internal ALB in front of the API"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the front-end only"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.ui.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "api" {
  name        = "${var.name}-api-sg"
  description = "Back-end instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "API port from the internal ALB"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.alb_internal.id]
  }

  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "RDS MySQL"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL from the API instance only"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.api.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
