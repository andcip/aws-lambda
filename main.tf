## General Serverless module to deploy a lambda application

#TODO: Lambda permission, add all triggers ( apig, alb, SNS, cognito, etc)

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "random_integer" "bucket_salt" {
  max = 9999999999
  min = 1000000000
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket        = "${var.lambda_name}-lambdaform-bucket-${random_integer.bucket_salt.result}"
  acl           = "private"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

locals {
  source_zipped = length(regexall(".zip$", var.source_dir)) > 0
}


data "archive_file" "files" {
  count = local.source_zipped ? 0 : 1
  type        = "zip"
  output_path = "${path.root}/lambda.zip"

  excludes = [for file in var.exclude_files : "${path.root}/${file}"]

  source_dir = var.source_dir
}

resource "aws_s3_bucket_object" "lambda_zip" {

  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "${var.lambda_name}.zip"
  source = local.source_zipped ? var.source_dir : data.archive_file.files[0].output_path

  etag = local.source_zipped ? filemd5(var.source_dir) : filemd5(data.archive_file.files[0].output_path)
}

resource "aws_iam_role" "function_role" {
  name               = "${var.lambda_name}_iam_role"
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
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda_name}:*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "function_policy" {
  count  = length(var.iam_policies)
  name   = "${var.lambda_name}_function_policy_${count.index}"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = var.iam_policies[count.index].actions
        Effect    = "Allow"
        Resource  = var.iam_policies[count.index].resources
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "function_policy_attach" {
  count      = length(var.iam_policies)
  role       = aws_iam_role.function_role.name
  policy_arn = aws_iam_policy.function_policy[count.index].arn
}

data "aws_iam_policy" "vpc_access_policy" {
  count = var.vpc_mode != null ? 1 : 0
  arn   = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

## DA PROVARE
data "aws_iam_policy" "xray_enable_policy" {
  count = var.tracing_mode != null ? 1 : 0
  arn   = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "xray_policy_attachment" {
  count      = var.tracing_mode != null ? 1 : 0
  role       = aws_iam_role.function_role.name
  policy_arn = data.aws_iam_policy.xray_enable_policy[count.index].arn
}

resource "aws_iam_role_policy_attachment" "vpc_policy_attachment" {
  count      = var.vpc_mode != null ? 1 : 0
  role       = aws_iam_role.function_role.name
  policy_arn = data.aws_iam_policy.vpc_access_policy[count.index].arn
}


resource "aws_lambda_function" "function" {

  depends_on = [
    aws_s3_bucket_object.lambda_zip,
    aws_cloudwatch_log_group.lambda_log_group
  ]

  function_name = var.lambda_name
  memory_size   = var.memory_size
  timeout       = var.timeout

  runtime       = var.lambda_runtime
  handler       = var.lambda_handler
  architectures = [var.architecture]
  role          = aws_iam_role.function_role.arn

  s3_bucket        = aws_s3_bucket.lambda_bucket.id
  s3_key           = aws_s3_bucket_object.lambda_zip.key
  reserved_concurrent_executions = var.concurrent_execution

  source_code_hash = local.source_zipped ? filebase64sha256(var.source_dir): data.archive_file.files[0].output_base64sha256

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

  dynamic "vpc_config" {
    for_each = var.vpc_mode == null ? [] : [true]
    content {
      security_group_ids = [aws_security_group.lambda_security_group[0].id]
      subnet_ids         = var.vpc_mode.subnet_ids
    }
  }
}

resource "aws_security_group" "lambda_security_group" {
  count  = var.vpc_mode != null ? 1 : 0
  vpc_id = var.vpc_mode.id

  dynamic "ingress" {
    for_each = try(var.vpc_mode.security_group.ingress == null ? [] : var.vpc_mode.security_group.ingress, [])
    content {
      description      = "Lambda sg"
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = try((ingress.value.cidr_blocks) > 0 ? ingress.value.cidr_blocks : [], [])
      security_groups  = try((ingress.value.security_groups) > 0 ? ingress.value.security_groups : [], [])
    }
  }

  dynamic "egress" {
    for_each = try(var.vpc_mode.security_group.egress == null ? [] : var.vpc_mode.security_group.egress, [])
    content {
      description      = "Lambda sg"
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = try(length(egress.value.cidr_blocks) > 0 ? egress.value.cidr_blocks : [], [])
      security_groups  = try(length(egress.value.security_groups) > 0 ? egress.value.security_groups : [], [])
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {

  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = var.log_retention

}

## TRIGGERS

## S3
module "trigger_s3" {
  count                = try(var.trigger.s3 != null ? 1 : 0, 0)
  source               = "./triggers/s3"
  lambda_function_arn  = aws_lambda_function.function.arn
  lambda_function_name = aws_lambda_function.function.function_name
  trigger              = var.trigger.s3
}

## REST
module "trigger_rest" {
  depends_on                 = [aws_lambda_function.function]
  count                      = try (var.trigger.apigateway.type == "REST" ? 1 : 0, 0)
  source                     = "./triggers/rest"
  stage_name                = var.stage_name
  lambda_function_invoke_arn = aws_lambda_function.function.invoke_arn
  lambda_function_name       = var.lambda_name
  timeout_milliseconds       = var.timeout != null ? var.timeout * 1000 : null
  trigger                    = var.trigger.apigateway
}

## HTTP
module "trigger_http" {
  depends_on                 = [aws_lambda_function.function]
  count                      = try(var.trigger.apigateway.type == "HTTP" ? 1 : 0, 0)
  source                     = "./triggers/http"
  stage_name                = var.stage_name
  lambda_function_invoke_arn = aws_lambda_function.function.invoke_arn
  lambda_function_name       = var.lambda_name
  timeout_milliseconds       = var.timeout != null ? var.timeout * 1000 : null
  trigger                    = var.trigger.apigateway
}
