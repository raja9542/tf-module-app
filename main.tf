resource "aws_iam_role" "role" {
  name = "${var.env}-${var.component}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    local.common_tags,
    {Name = "${var.env}-${var.component}-role"}
  )
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.env}-${var.component}-role"
  role = aws_iam_role.role.name
}


resource "aws_security_group" "main" {
  name        = "${var.env}-${var.component}-security-group"
  description = "${var.env}-${var.component}-security-group" // any name
  vpc_id      = var.vpc_id

  ingress {
    description      = "HTTP"
    from_port        = var.app_port
    to_port          = var.app_port
    protocol         = "tcp"
    cidr_blocks      = var.allow_cidr // to allow app cidr block
  }
# we need ssh from workstation bastion node
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.bastion_cidr // to allow app cidr block
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {Name = "${var.env}-${var.component}-security-group"}
  )
}


resource "aws_launch_template" "main" {
  name_prefix   = "${var.env}-${var.component}-template"
  image_id      = data.aws_ami.centos8.id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.main.id]
}

resource "aws_autoscaling_group" "bar" {
  name                      = "${var.env}-${var.component}-asg" # asg--auto scaling group
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  force_delete              = true  #force_delete - (Optional) Allows deleting the Auto Scaling Group without waiting for all instances in the pool to terminate
  vpc_zone_identifier       = var.subnet_ids # which subnets/Az we need to create

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = local.all_tags
    content {
      key = tag.value.key
      value = tag.value.value
      propagate_at_launch = true
    }
  }
}