data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_apigatewayv2_api" "api" {
  name          = "${var.lambda_function_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "stage" {

  api_id      = aws_apigatewayv2_api.api.id
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

  api_id               = aws_apigatewayv2_api.api.id
  integration_uri      = var.lambda_function_invoke_arn
  timeout_milliseconds = var.timeout_milliseconds
  integration_type     = "AWS_PROXY"
  integration_method   = "POST"
}

/*resource "aws_lambda_permission" "authorizer_permission" {

  count         = var.trigger.authorizer != null ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.trigger.authorizer.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:api-id/authorizers/${aws_apigatewayv2_authorizer.authorizer[0].id}"
}*/

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
  api_id                            = aws_apigatewayv2_api.api.id
  authorizer_type                   = var.trigger.authorizer == null ? "JWT" : "REQUEST"
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
}

resource "aws_apigatewayv2_route" "api_route" {

  count              = length(var.trigger.routes)
  api_id             = aws_apigatewayv2_api.api.id
  authorization_type = try(var.trigger.authorizer != null && var.trigger.routes[count.index].authorizer, false) ? local.auth_type : "NONE"
  authorizer_id      = try(var.trigger.authorizer != null && var.trigger.routes[count.index].authorizer, false) ? aws_apigatewayv2_authorizer.authorizer[0].id : null
  route_key          = "${var.trigger.routes[count.index].method} ${var.trigger.routes[count.index].path}"
  target             = "integrations/${aws_apigatewayv2_integration.api_integration.id}"
}

resource "aws_cloudwatch_log_group" "apigateway_log_group" {

  name              = "/aws/api_gw/${aws_apigatewayv2_api.api.name}"
  retention_in_days = var.log_retention
}

resource "aws_lambda_permission" "api_gw_lambda_invoke_permission" {

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
