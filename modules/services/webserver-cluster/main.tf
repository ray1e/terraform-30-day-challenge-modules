/* terraform {
  backend "s3" {
    bucket = "terraform-up-and-running-state-2c1ab3b29e8ffc0221983305ac2bce60"
    key = "stage/services/webserver-cluster/terraform.tfstate"
    region = "us-east-2"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt = true
  }
} */

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key = var.db_remote_state_key
    region = "us-east-2"

  }
}

/* data "aws_vpc" "default" {
    default = true
} */

data  "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

data "aws_ami" "ubuntu_20_04" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

locals {
  http_port = 80
  any_port = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips = ["0.0.0.0/0"]
}


/* resource "aws_instance" "terraform-example" {
    ami = "ami-0fb0b230890ccd1e6"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.instance.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, world" > index.html
                nohup busybox httpd -f -p 80 &
                EOF
    
    user_data_replace_on_change = true
    tags = {
      Name = "terraform-example"
    }
} */

## security group
resource "aws_security_group" "instance" {
    name = "${var.cluster_name}-instance"
}


resource "aws_security_group_rule" "allow_http_inbound" {
  type = "ingress"
  security_group_id = aws_security_group.instance.id
  from_port = var.server_port
  to_port = var.server_port
  protocol = local.tcp_protocol
  cidr_blocks = local.all_ips

}

resource "aws_security_group_rule" "allow_all_outbound" {
  type = "egress"
  security_group_id = aws_security_group.instance.id
  from_port = local.any_port
  to_port = local.any_port
  protocol = local.any_protocol
  cidr_blocks = local.all_ips
}

## launch template - instance configuration information
resource "aws_launch_template" "launch-template" {
    image_id = data.aws_ami.ubuntu_20_04.id
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.instance.id]

    user_data = base64encode(
      templatefile("${path.module}/user-data.sh", {
        server_port = var.server_port
        db_address = data.terraform_remote_state.db.outputs.address
        db_port = data.terraform_remote_state.db.outputs.port
      }) 
    ) 
    
}

resource "aws_autoscaling_group" "asg-example" {
    min_size = var.min_size
    max_size = var.max_size
    vpc_zone_identifier = data.aws_subnets.default.ids
    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"

    launch_template {
      id = aws_launch_template.launch-template.id
      version = "$Latest"
    }

    tag {
        key = "Name"
        value = "${var.cluster_name}"
        propagate_at_launch = true
    }
}

#load balancer
resource "aws_lb" "load-balancer" {
    name = "test-lb"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.alb.id]
}

# security group for the load balancer
resource "aws_security_group" "alb" {
    name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "alb_allow_http_inbound" {
  type = "ingress"
  security_group_id = aws_security_group.alb.id
  from_port =local.http_port
  to_port = local.http_port
  protocol = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "alb_allow_all_outbound" {
  type = "egress"
  security_group_id = aws_security_group.alb.id
  from_port = local.any_port
  to_port = local.any_port
  protocol = local.any_protocol
  cidr_blocks = local.all_ips
}

# Load balancer listener
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.load-balancer.arn
    port = local.http_port
    protocol = "HTTP"

    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code = 404
      }
    }
        
}

# target group
resource "aws_lb_target_group" "asg" {
    name = "test-asg"
    port = local.http_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
      path = "/"
      protocol = "HTTP"
      matcher = "200"
      interval = 15
      timeout = 3
      healthy_threshold = 2
      unhealthy_threshold = 2
    }
}

# listner rules
resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100

    condition {
      path_pattern {
        values = ["*"]
      }
    } 

    action {
      type = "forward"
      target_group_arn = aws_lb_target_group.asg.arn
    }
}

