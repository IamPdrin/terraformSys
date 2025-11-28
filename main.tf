terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

variable "aws_access_key" {
  type = string
}
variable "aws_secret_key" {
  type = string
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}


provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = "us-east-1"
}

# pega a região em runtime para construir URIs
data "aws_region" "current" {}

# --------------------------------------------------
# Rede (VPC, 2 public subnets, 2 private subnets, IGW, route tables)
# --------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "tf-vpc" }
}

# Public subnets (2 AZs)
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = { Name = "tf-public-subnet-1" }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.11.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "tf-public-subnet-2" }
}

# Private subnets (2 AZs)
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "tf-private-subnet-1" }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "tf-private-subnet-2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "tf-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "tf-public-rt" }
}

resource "aws_route_table_association" "public_assoc1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_assoc2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_rt.id
}

# --------------------------------------------------
# EC2 (public subnet)
# --------------------------------------------------

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # opcional: SSH (remova em produção)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-sg" }
}

resource "aws_instance" "web" {
  ami                         = "ami-0c02fb55956c7d316" # Amazon Linux 2 (us-east-1) - pode atualizar se quiser
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public1.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  tags = { Name = "tf-ec2" }
}

# --------------------------------------------------
# S3 (nome com sufixo aleatório para evitar conflito global)
# --------------------------------------------------

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "bucket" {
  bucket = "tf-s3-bucket-pedro-${random_id.bucket_suffix.hex}"
  tags   = { Name = "tf-s3-bucket" }
}

resource "aws_s3_bucket_public_access_block" "bucket_block" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# --------------------------------------------------
# Lambda (Python Hello World) - NOTE: precisa do arquivo lambda.zip local
# --------------------------------------------------

resource "aws_iam_role" "lambda_role" {
  name = "lambda-basic-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject","s3:GetObject","s3:ListBucket"]
        Resource = [
          aws_s3_bucket.bucket.arn,
          "${aws_s3_bucket.bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# A Lambda espera que exista lambda.zip no mesmo diretório do main.tf
resource "aws_lambda_function" "hello_lambda" {
  function_name = "helloLambda"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "index.lambda_handler"

  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")
}

# --------------------------------------------------
# API Gateway (REST) integrado com Lambda
# --------------------------------------------------

resource "aws_api_gateway_rest_api" "api" {
  name        = "tf-api"
  description = "API Gateway criado via Terraform"
}

resource "aws_api_gateway_resource" "hello_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.hello_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# URI precisa do formato especial para integ. com Lambda
resource "aws_api_gateway_integration" "hello_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.hello_resource.id
  http_method             = aws_api_gateway_method.hello_get.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.hello_lambda.arn}/invocations"
}

resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [aws_api_gateway_integration.hello_integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "api_stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = "prod"
}


# --------------------------------------------------
# ECS FARGATE - minimal (usa imagem pública nginx)
# --------------------------------------------------

resource "aws_security_group" "ecs_sg" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
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

  tags = { Name = "ecs-sg" }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "main" {
  name = "cluster-simples"
}

resource "aws_ecs_task_definition" "task" {
  family                   = "task-simples"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "nginx"
      essential = true
      portMappings = [
        { containerPort = 80, hostPort = 80 }
      ]
    }
  ])
}

resource "aws_ecs_service" "service" {
  name            = "service-simples"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    assign_public_ip = true
    subnets          = [aws_subnet.public1.id, aws_subnet.public2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_exec_policy]
}

# --------------------------------------------------
# RDS PostgreSQL (em subnets privadas)
# --------------------------------------------------

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Permitir conexao ao RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # permite VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [ aws_subnet.private1.id, aws_subnet.private2.id ]
  description = "Subnets privadas para o RDS"
}

resource "random_password" "rds_password" {
  length           = 16
  override_special = "!#$%&*()_+-=<>?{}[]"  # apenas caracteres permitidos pelo RDS
}

resource "aws_db_instance" "postgres1" {
  identifier            = "meu-postgres"
  engine                = "postgres"
  engine_version        = "15.8"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 50
  db_name               = "appdb"
  username              = "postgres"
  password              = random_password.rds_password.result

  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name

  deletion_protection = false
  multi_az            = false
  storage_encrypted   = true
}

# --------------------------------------------------
# OUTPUTS
# --------------------------------------------------

output "ec2_public_ip" {
  description = "IP público da EC2"
  value       = aws_instance.web.public_ip
}

output "ec2_public_dns" {
  description = "DNS público da EC2"
  value       = aws_instance.web.public_dns
}

output "s3_bucket_name" {
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.bucket.bucket
}

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL"
  value       = aws_db_instance.postgres1.address
}

output "rds_password" {
  description = "Senha gerada para o RDS (sensitive)"
  value       = random_password.rds_password.result
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_task_definition" {
  description = "ARN da Task Definition ECS"
  value       = aws_ecs_task_definition.task.arn
}

output "api_gateway_url" {
  description = "URL pública do API Gateway (endpoint /hello)"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}/hello"
}

output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "IDs das subnets públicas"
  value       = [ aws_subnet.public1.id, aws_subnet.public2.id ]
}

output "private_subnets" {
  description = "IDs das subnets privadas"
  value       = [ aws_subnet.private1.id, aws_subnet.private2.id ]
}
