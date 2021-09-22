## General Serverless module to deploy a lambda application

#TODO: Lambda permission, add all triggers ( apig, alb, SNS, cognito, etc)

data "aws_caller_identity" "current" {}


data "aws_subnet" "private_subnets" {
  count = var.vpc_id != null ? 1 : 0
  vpc_id = var.vpc_id
  filter {
    name = "tag:Type"
    values = ["Private"]
  }
}

data "aws_vpc" "vpc" {
  count = var.vpc_id != null ? 1 : 0
  id = var.vpc_id
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "${var.lambda_name}-lambda"
  acl = "private"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}


data "archive_file" "files" {
  type = "zip"
  output_path = "${path.module}/lambda.zip"
  excludes = [for file in var.exclude_files : "${path.module}/${file}"]

  source_dir = "${path.module}/"
}

resource "aws_s3_bucket_object" "lambda_zip" {

  bucket = aws_s3_bucket.lambda_bucket.id
  key = "${var.lambda_name}.zip"
  source = data.archive_file.files.output_path

  etag = filemd5(data.archive_file.files.output_path)
}

resource "aws_iam_role" "function_role" {
  name = "${var.lambda_name}_iam_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  tags = var.tags
}

resource "aws_iam_role_policy" "function_logging_policy" {
  role = aws_iam_role.function_role.id
  name = "${var.lambda_name}_logging_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup","ssm:GetParametersByPath"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs::${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda_name}:*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "function_policy" {
  count = var.iam_policies
  name = "${var.lambda_name}_function_policy_${count.index}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Actions = var.iam_policies[count.index].actions
        Effect = "Allow"
        Principal = var.iam_policies[count.index].principal
        Resource = var.iam_policies[count.index].resource
      }
    ]
  })
}


data "aws_iam_policy" "vpc_access_policy" {
  count = var.vpc != null ? 1 : 0
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_policy_attachment" {
  count = var.vpc != null ? 1 : 0
  role = aws_iam_role.function_role.name
  policy_arn = data.aws_iam_policy.vpc_access_policy.arn
}

## DA PROVARE
data "aws_iam_policy" "xray_enable_policy" {
  count = var.tracing_mode != null ? 1 : 0
  arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "vpc_policy_attachment" {
  count = var.tracing_mode != null ? 1 : 0
  role = aws_iam_role.function_role.name
  policy_arn = data.aws_iam_policy.xray_enable_policy.arn
}


resource "aws_lambda_function" "function" {

  depends_on = [
    aws_s3_bucket_object.lambda_zip,
    aws_cloudwatch_log_group.lambda_log_group
  ]

  function_name = var.lambda_name
  memory_size = var.memory_size
  timeout = var.timeout

  runtime = var.lambda_runtime
  handler = var.lambda_handler

  role = aws_iam_role.function_role.arn

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key = aws_s3_bucket_object.lambda_zip.key

  source_code_hash = data.archive_file.files.output_base64sha256

  dynamic "environment" {
    for_each = length(keys(var.environment_variables)) == 0 ? [] : [true]
    content {
      variables = var.environment_variables
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_mode == null ? [] : [true]
    content {
      mode = var.tracing_mode
    }
  }

  # TODO get only vpc id
  dynamic "vpc_config" {
    for_each = var.vpc_id == null ? [] : [true]
    content {
      security_group_ids = [aws_security_group.lambda_security_group.id]
      subnet_ids = data.aws_subnet.private_subnets[0].*.id
    }
  }

  tags = var.tags

}

resource "aws_security_group" "lambda_security_group" {
  count = var.vpc_id != null ? 1 : 0
  vpc_id = var.vpc_id
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {

  name = "/aws/lambda/${var.lambda_name}"
  retention_in_days = var.log_retention
  tags = var.tags
}

## TRIGGERS

## S3
module "trigger_s3" {
  source = "./triggers/s3"
  lambda_function_arn = aws_lambda_function.function.arn
  lambda_function_name = aws_lambda_function.function.function_name
  trigger = var.trigger.s3
}

module "api_gateway" {
  source = "./triggers/api-gateway"
  environment = var.environment
  lambda_function_invoke_arn = aws_lambda_function.function.invoke_arn
  lambda_function_name = var.lambda_name
  timeout_milliseconds = var.timeout * 1000
  trigger = var.trigger.apigateway
}
