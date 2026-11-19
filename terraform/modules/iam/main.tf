data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "read_params" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/*"]
  }
}

data "aws_iam_policy_document" "describe_instances" {
  statement {
    actions   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
    resources = ["*"]
  }
}

# ---- app instances (UI/API): CloudWatch agent + read this environment's parameters only
resource "aws_iam_role" "app" {
  name               = "${var.name}-app-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "app_cw" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "app_params" {
  name   = "read-params"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.read_params.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app-profile"
  role = aws_iam_role.app.name
}

# ---- bastion (Ansible controller): read params + dynamic inventory (DescribeInstances)
resource "aws_iam_role" "bastion" {
  name               = "${var.name}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "bastion_params" {
  name   = "read-params"
  role   = aws_iam_role.bastion.id
  policy = data.aws_iam_policy_document.read_params.json
}

resource "aws_iam_role_policy" "bastion_describe" {
  name   = "describe-instances"
  role   = aws_iam_role.bastion.id
  policy = data.aws_iam_policy_document.describe_instances.json
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-bastion-profile"
  role = aws_iam_role.bastion.name
}
