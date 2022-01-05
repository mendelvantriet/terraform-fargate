terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    key    = "fargate.tfstate"
  }
}

provider "aws" {
  region = "${var.region}"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.11.0"

  name = "${var.name}"
  cidr = "${var.cidr_block}"

  azs             = "${var.zones}"
  intra_subnets   = "${var.intra_subnets}"
  public_subnets  = "${var.public_subnets}"

  enable_nat_gateway = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = "${var.tags}"
}

# s3
data "aws_s3_bucket" "selected" {
  bucket = var.bucket
}

resource "aws_s3_bucket_policy" "allow_access_from_fargate" {
  bucket = data.aws_s3_bucket.selected.id
  policy = data.aws_iam_policy_document.allow_access_from_vpc.json
}

data "aws_iam_policy_document" "allow_access_from_vpc" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ecs_task_role.arn]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      data.aws_s3_bucket.selected.arn,
      "${data.aws_s3_bucket.selected.arn}/*",
    ]
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

# Make s3 available for vpc
#resource "aws_vpc_endpoint" "s3" {
#  vpc_id       = "${module.vpc.vpc_id}"
#  service_name = "com.amazonaws.${var.region}.s3"
#}
#resource "aws_vpc_endpoint_route_table_association" "s3" {
#  count           = "${length(module.vpc.intra_route_table_ids)}"
#  route_table_id  = "${module.vpc.intra_route_table_ids[count.index]}"
#  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
#}

# ecr vpce
resource "aws_vpc_endpoint" "ecr" {
  vpc_id       = "${module.vpc.vpc_id}"
  service_name = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  security_group_ids = [aws_security_group.allow_tls.id]
}
resource "aws_vpc_endpoint" "ecr-api" {
  vpc_id       = "${module.vpc.vpc_id}"
  service_name = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type = "Interface"
  security_group_ids = [aws_security_group.allow_tls.id]
}

resource "aws_ecs_cluster" "cluster" {
  name = "public-fargate"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "fargate_task_execution_role"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}
resource "aws_iam_role" "ecs_task_role" {
  name = "fargate_demo_task_role"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_cloudwatch_log_group" "log-group" {
  name = "/tasks/fargate-demo"
  retention_in_days = "${var.log_retention_in_days}"
  tags = "${var.tags}"
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = "${aws_iam_role.ecs_task_execution_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "task_logging" {
  role       = "${aws_iam_role.ecs_task_execution_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
resource "aws_iam_role_policy_attachment" "task_s3" {
  role       = "${aws_iam_role.ecs_task_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_ecs_task_definition" "definition" {
  family                   = "fargate_demo_task_definition"
  task_role_arn            = "${aws_iam_role.ecs_task_role.arn}"
  execution_role_arn       = "${aws_iam_role.ecs_task_execution_role.arn}"
  network_mode             = "awsvpc"
  cpu                      = "${var.cpu}"
  memory                   = "${var.memory}"
  requires_compatibilities = ["FARGATE"]
  container_definitions = <<DEFINITION
[
  {
    "image": "${var.registry}/${var.image}:${var.tag}",
    "name": "demo-container",
    "entrypoint": ["/opt/aws_ecs_entrypoint.sh"],
    "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-region" : "${var.region}",
                    "awslogs-group" : "${aws_cloudwatch_log_group.log-group.name}",
                    "awslogs-stream-prefix" : "fargate-demo"
                }
            },
    "environment": ${jsonencode(var.environment_variables)}
    }
]
DEFINITION

  tags = "${var.tags}"
}

