terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.56"
    }
  }

  backend "s3" {
    bucket = "vyrostkov-terraform"
    key    = "awsplay/terraform.tfstate"
    region = "eu-west-2"
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "${var.aws_region}a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "${var.aws_region}b"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "${var.aws_region}c"
}

resource "aws_ecs_cluster" "awsplay" {
  name = "awsplay"
}

resource "aws_ecs_task_definition" "awsplay" {
  family                   = "awsplay"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "awsplay",
      "image": "${var.image}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-create-group": "true",
          "awslogs-group": "/ecs/awsplay",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = aws_iam_role.awsplay_task_execution_role.arn
  task_role_arn            = aws_iam_role.awsplay_task_role.arn
}

resource "aws_iam_role" "awsplay_task_execution_role" {
  name               = "awsplay-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "awsplay_task_execution_role_policy" {
  role       = aws_iam_role.awsplay_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "awsplay_task_role" {
  name               = "awsplay-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "awsplay_task_role_policy" {
  role       = aws_iam_role.awsplay_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_alb" "awsplay_lb" {
  name               = "awsplay-lb"
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}",
    "${aws_default_subnet.default_subnet_c.id}"
  ]
  # Referencing the security group
  security_groups = ["${aws_security_group.awsplay_lb_security_group.id}"]
}

resource "aws_security_group" "awsplay_lb_security_group" {
  name = "awsplay_lb_security_group"
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "fargate" {
  name        = "fargate"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.awsplay_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = var.acm_cert_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fargate.arn
  }
}

resource "aws_ecs_service" "awsplay_service" {
  name            = "awsplay-service"
  cluster         = aws_ecs_cluster.awsplay.id
  task_definition = aws_ecs_task_definition.awsplay.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.fargate.arn
    container_name   = aws_ecs_task_definition.awsplay.family
    container_port   = 80 # Specifying the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true
    security_groups  = ["${aws_security_group.awsplay_fargate_security_group.id}"]
  }
}

resource "aws_security_group" "awsplay_fargate_security_group" {
  name = "awsplay_fargate_security_group"
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.awsplay_lb_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route53_record" "awsplay" {
  zone_id = var.route53_zone
  name    = var.route53_domain
  type    = "A"

  alias {
    name                   = aws_alb.awsplay_lb.dns_name
    zone_id                = aws_alb.awsplay_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_dynamodb_table" "awsplay" {
  name         = "awsplay"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}