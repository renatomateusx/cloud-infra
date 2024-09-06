provider "aws" {
  region = var.aws_region
}

# Criar um par de chaves SSH
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Segurança para a instância EC2
resource "aws_security_group" "web_sg" {
  name_prefix = "web-sg"
  description = "Allow HTTP and SSH"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrinja para IPs específicos em produção
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Instância EC2
# Definir uma lista de zonas de disponibilidade
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Criar instâncias EC2 em múltiplas zonas de disponibilidade
resource "aws_instance" "web" {
  count         = length(var.availability_zones)
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.web_sg.name]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "WebServer-${count.index + 1}"
  }
}

# Launch Configuration para Auto Scaling
resource "aws_launch_configuration" "web" {
  name          = "web-launch-configuration"
  image_id      = "ami-0c55b159cbfafe1f0"
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.web_sg.name]

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  launch_configuration = aws_launch_configuration.web.id
  min_size             = 2
  max_size             = 4
  desired_capacity     = 2
  availability_zones   = var.availability_zones
  vpc_zone_identifier  = [aws_vpc.main.id]

  tag {
    key                 = "Name"
    value               = "WebServer"
    propagate_at_launch = true
  }

  health_check_type          = "EC2"
  health_check_grace_period  = 300
  wait_for_capacity_timeout     = "0"
}

# Auto Scaling Policy
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}



# Segurança para o RDS
resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-sg"
  description = "Allow MySQL traffic"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Ajuste conforme necessário
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instância RDS MySQL
resource "aws_db_instance" "mysql" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t2.micro"
  name                 = var.db_name
  username             = var.db_user
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Habilitar Alta Disponibilidade
  multi_az = true

  storage_encrypted = true

  backup_retention_period = 7  # Manter backups por 7 dias
}

# Load Balancer
resource "aws_elb" "web_lb" {
  name               = "web-load-balancer"
  availability_zones = ["us-east-1a", "us-east-1b"]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances = [aws_instance.web.id]

  tags = {
    Name = "WebLoadBalancer"
  }
}

resource "aws_ebs_volume" "data" {
  size              = 100
  availability_zone = var.availability_zones[0]
  encrypted         = true
}

# CloudWatch Alarm para CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 high cpu utilization"
  dimensions = {
    InstanceId = aws_instance.web.id
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
  ok_actions    = [aws_autoscaling_policy.scale_in.arn]
}
