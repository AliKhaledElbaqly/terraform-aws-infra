locals {
  common_tags = {
    terraform = "true"
  }
}

// Define the main VPC
resource "aws_vpc" "mainvpc" {
  cidr_block = var.vpc_cidr

  tags = merge(local.common_tags, {
    Name        = var.vpc_name
    Environment = "test_environment"
  })
}

// Define public subnets
resource "aws_subnet" "public_subnets" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.mainvpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${each.key}_public_subnet"
  })
}

// Define private subnets
resource "aws_subnet" "private_subnets" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.mainvpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = each.key

  tags = merge(local.common_tags, {
    Name = "${each.key}_private_subnet"
  })
}

// Create internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.mainvpc.id

  tags = {
    Name = "project_igw"
  }
}

// Create EIP for NAT
resource "aws_eip" "nat_gateway_eip" {
  domain     = "vpc"
depends_on = [aws_internet_gateway.`]

  tags = {
    Name = "terra_eip"
  }
}

// Create NAT gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets["eu-north-1a"].id

  depends_on = [aws_subnet.public_subnets]

  tags = {
    Name = "terra_nat_gateway"
  }
}

// Route table for private subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.mainvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = merge(local.common_tags, {
    Name = "private_rtb"
  })
}

// Associate route table with private subnets
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}

// Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mainvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = merge(local.common_tags, {
    Name = "public_rtb"
  })
}

// Associate route table with public subnets
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

// Security group for EC2
resource "aws_security_group" "webSG" {
  name   = "WebSG"
  vpc_id = aws_vpc.mainvpc.id

  dynamic "ingress" {
    for_each = var.allowed_ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "web-sg"
  })
}

// SSH key pair
resource "aws_key_pair" "SSH" {
  key_name   = "AuthSSH"
  public_key = file("~/.ssh/authkey.pub")
}

// AMI Data
data "aws_ami" "getami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

// EC2 Instance 1
resource "aws_instance" "myec2" {
  ami                         = data.aws_ami.getami.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.SSH.key_name
  availability_zone           = keys(var.private_subnets)[0]
  subnet_id                   = values(aws_subnet.private_subnets)[0].id
  vpc_security_group_ids      = [aws_security_group.webSG.id]

  root_block_device {
    encrypted = true
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install httpd -y
    systemctl start httpd
    systemctl enable httpd
    echo "This is server *1* in AWS Region eu-north-1" > /var/www/html/index.html
  EOF

  tags = {
    Name = "web_instance_1"
  }
}

// EC2 Instance 2
resource "aws_instance" "app" {
  ami                         = data.aws_ami.getami.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.SSH.key_name
  availability_zone           = keys(var.private_subnets)[1]
  subnet_id                   = values(aws_subnet.private_subnets)[1].id
  vpc_security_group_ids      = [aws_security_group.webSG.id]

  root_block_device {
    encrypted = true
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install httpd -y
    systemctl start httpd
    systemctl enable httpd
    echo "This is server *2* in AWS Region eu-north-1" > /var/www/html/index.html
  EOF

  tags = {
    Name = "web_instance_2"
  }
}

// ALB Security Group
resource "aws_security_group" "ALBSG" {
  name        = "ALBSG"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.mainvpc.id

  dynamic "ingress" {
    for_each = var.allowed_ports_alb
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}
// ALB
resource "aws_lb" "project_alb" {
  name               = "project-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALBSG.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  tags = {
    Name = "project-alb"
  }
}
// Target Group
resource "aws_lb_target_group" "project_tg" {
  name     = "target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.mainvpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "target-group"
  }
}

// Listener
resource "aws_lb_listener" "listener_lb" {
  load_balancer_arn = aws_lb.project_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.project_tg.arn
  }
}
// Launch Template
resource "aws_launch_template" "scaled_template" {
  name_prefix            = "scaled_launch_instance"
  image_id               = data.aws_ami.getami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.webSG.id]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "project-alb"
    Environment = "dev"
  }
}
// Auto Scaling Group
resource "aws_autoscaling_group" "ec2_auto_scaling" {
  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  launch_template {
    id = aws_launch_template.scaled_template.id
  }

  vpc_zone_identifier = [for subnet in aws_subnet.private_subnets : subnet.id]

  tag {
    key                 = "Name"
    value               = "autoscaled-ec2"
    propagate_at_launch = true
  }
}

// ASG Target Group Attachment
resource "aws_autoscaling_attachment" "asg_tg" {
  autoscaling_group_name = aws_autoscaling_group.ec2_auto_scaling.id
  lb_target_group_arn    = aws_lb_target_group.project_tg.arn
}
// RDS Subnet Group
resource "aws_db_subnet_group" "db_subnet" {
  name       = "rds-db-subnet"
  subnet_ids = [for subnet in aws_subnet.private_subnets : subnet.id]

  tags = {
    Name = "rds-db-subnet"
  }
}
// RDS Security Group
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.mainvpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.webSG.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}
// RDS Instance
resource "aws_db_instance" "rds_instance" {
  allocated_storage      = 20
  identifier             = "rds-terraform"
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  publicly_accessible    = false
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Name = "rds-instance"
  }
}
