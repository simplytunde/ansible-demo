provider "aws"{
    region = "us-west-1"
}
data "aws_availability_zones" "available" {}
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2_security_group"
  description = "allow traffic on port 22 and 8080"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = ["${aws_security_group.elb_security_group.id}"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "elb_security_group" {
  name        = "elb_security_group"
  description = "allow traffic on port 22 and 8080"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_launch_configuration" "webserver_launch_config" {
  name_prefix   = "ansible-demo-"
  image_id      = "${var.image_ami}"
  instance_type = "t2.small"
  key_name      = "${var.key_name}"
  security_groups = ["${aws_security_group.ec2_security_group.name}"]
  root_block_device = {
      volume_type = "gp2"
      volume_size = "20"
  }
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_group" "app_autoscaling_group" {
  availability_zones        = ["${data.aws_availability_zones.available.names}"]
  name                      = "ansible-demo-autoscaling"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.webserver_launch_config.name}"
  load_balancers            = ["${aws_elb.ansible-load-balancer.id}"]


  tags = [
    {
      key                 = "Name"
      value               = "app-server-autoscaling-group"
      propagate_at_launch = true
    },
    {
      key                 = "env"
      value               = "prod"
      propagate_at_launch = true
    },
    {
      key                 = "type"
      value               = "webserver"
      propagate_at_launch = true
    },
  ]

  timeouts {
    delete = "15m"
  }

}

resource "aws_elb" "ansible-load-balancer" {
  name               = "ansible-demo-app-load-balancer"
  availability_zones = ["${data.aws_availability_zones.available.names}"]
  security_groups    = ["${aws_security_group.elb_security_group.id}"]
  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8080/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "ansible-demo-app-lb"
  }
}
