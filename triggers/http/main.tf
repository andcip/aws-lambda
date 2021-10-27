data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_apigatewayv2_api" "existing_api" {
  count  = var.trigger.existing_api_id != null ? 1 : 0
  api_id = var.trigger.existing_api_id
}

resource "aws_apigatewayv2_api" "api" {
  count         = var.trigger.existing_api_id != null ? 0 : 1
  name          = "${var.lambda_function_name}-api"
  protocol_type = "HTTP"
  disable_execute_api_endpoint = var.trigger.disable_test_endpoint == null ? false : var.trigger.disable_test_endpoint
  dynamic "cors_configuration" {
    for_each = var.trigger.cors_configuration == null ? [] : [true]
    content {
      allow_headers = var.trigger.cors_configuration.allow_headers
      allow_methods = var.trigger.cors_configuration.allow_method
      allow_origins = var.trigger.cors_configuration.allow_origins
      max_age       = var.trigger.cors_configuration.max_age
    }
  }
}

locals {
  api_id = var.trigger.existing_api_id != null ? var.trigger.existing_api_id : aws_apigatewayv2_api.api[0].id
  api_execution_arn = var.trigger.existing_api_id != null ? data.aws_apigatewayv2_api.existing_api[0].execution_arn : aws_apigatewayv2_api.api[0].execution_arn
  api_name =  var.trigger.existing_api_id != null ? data.aws_apigatewayv2_api.existing_api[0].name : aws_apigatewayv2_api.api[0].name
}


resource "aws_apigatewayv2_stage" "stage" {

  api_id      = local.api_id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway_log_group.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}


resource "aws_apigatewayv2_integration" "api_integration" {

  api_id               = local.api_id
  integration_uri      = var.lambda_function_invoke_arn
  timeout_milliseconds = var.timeout_milliseconds
  payload_format_version = "2.0"
  integration_type     = "AWS_PROXY"
  integration_method   = "POST"
}

resource "aws_iam_role" "authorizer_invocation_role" {
  count = var.trigger.authorizer != null ? 1 : 0
  name  = "authorizer_api_gateway_role"
  path  = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "invocation_policy" {
  count = var.trigger.authorizer != null ? 1 : 0
  name  = "authorizer_apig_invoke_policy"
  role  = aws_iam_role.authorizer_invocation_role[0].id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.trigger.authorizer.name}"
    }
  ]
}
EOF
}

resource "aws_apigatewayv2_authorizer" "authorizer" {
  count                             = var.trigger.authorizer != null ? 1 : 0
  api_id                            = local.api_id
  authorizer_type                   = var.trigger.authorizer.jwt == null ? "REQUEST" : "JWT"
  name                              = var.trigger.authorizer.name
  identity_sources                  = [var.trigger.authorizer.identity_source]
  authorizer_uri                    = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.trigger.authorizer.name}/invocations"
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  authorizer_credentials_arn        = aws_iam_role.authorizer_invocation_role[0].arn
  dynamic "jwt_configuration" {
    for_each = var.trigger.authorizer.jwt != null ? [true] : []
    content {
      audience = var.trigger.authorizer.jwt.aud
      issuer   = var.trigger.authorizer.jwt.issuer
    }
  }
}

locals {
  auth_type = try(aws_apigatewayv2_authorizer.authorizer[0].authorizer_type == "REQUEST" ? "CUSTOM" : "JWT", "NONE")
  route_depend = try(var.trigger.authorizer != null && var.trigger.routes[count.index].authorizer, false) ? aws_apigatewayv2_authorizer.authorizer[0] : null
}

resource "aws_apigatewayv2_route" "api_route" {

  count              = length(var.trigger.routes)
  depends_on         = [local.route_depend]
  api_id             = local.api_id
  authorization_type = try(var.trigger.authorizer != null && var.trigger.routes[count.index].authorizer, false) ? local.auth_type : "NONE"
  authorizer_id      = try(var.trigger.authorizer != null && var.trigger.routes[count.index].authorizer, false) ? aws_apigatewayv2_authorizer.authorizer[0].id : null
  route_key          = "${var.trigger.routes[count.index].method} ${var.trigger.routes[count.index].path}"
  target             = "integrations/${aws_apigatewayv2_integration.api_integration.id}"
}

resource "aws_cloudwatch_log_group" "apigateway_log_group" {

  name              = "/aws/api_gw/${local.api_name}"
  retention_in_days = var.log_retention
}

resource "aws_lambda_permission" "api_gw_lambda_invoke_permission" {

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${local.api_execution_arn}/*/*"
}
