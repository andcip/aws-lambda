## General Serverless module to deploy a lambda application

#TODO: Lambda permission, add all triggers ( apig, alb, SNS, etc)

data "aws_subnet" "private_subnets" {
  filter {
    name = "tag:Type"
    values = ["Private"]
  }
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
  //TODO role but permission in input
  role = aws_iam_role.lambda_exec.arn

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key = aws_s3_bucket_object.lambda_zip.key

  source_code_hash = data.archive_file.files.output_base64sha256

  dynamic "environment" {
    for_each = length(keys(var.environment_variables)) == 0 ? [] : [
      true]
    content {
      variables = var.environment_variables
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_mode == null ? [] : [
      true]
    content {
      mode = var.tracing_mode
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc ? [true] : []
    content {
      security_group_ids = [aws_security_group.lambda_security_group.id]
      subnet_ids = data.aws_subnet.private_subnets.*.id
    }
  }

  tags = var.tags

}

resource "aws_security_group" "lambda_security_group" {
  count = var.vpc ? 1 : 0
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
