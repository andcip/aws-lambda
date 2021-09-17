## API GATEWAY

resource "aws_apigatewayv2_api" "api" {
  count = var.trigger.apigateway != null ? 1 : 0
  name = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "stage" {
  count = var.trigger.apigateway != null ? 1 : 0

  api_id = aws_apigatewayv2_api.api.id

  name = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway_log_group.arn

    format = jsonencode({
      requestId = "$context.requestId"
      sourceIp = "$context.identity.sourceIp"
      requestTime = "$context.requestTime"
      protocol = "$context.protocol"
      httpMethod = "$context.httpMethod"
      resourcePath = "$context.resourcePath"
      routeKey = "$context.routeKey"
      status = "$context.status"
      responseLength = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    }
    )
  }
}


resource "aws_apigatewayv2_integration" "api_integration" {

  count = var.trigger.apigateway != null ? 1 : 0

  api_id = aws_apigatewayv2_api.api.id
  integration_uri = var.lambda_function_invoke_arn
  timeout_milliseconds = var.timeout
  integration_type = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "api_route" {

  count = var.trigger.apigateway != null ? length(var.trigger.apigateway.routes) : 0
  api_id = aws_apigatewayv2_api.api.id
  route_key = var.trigger.apigateway.routes[count.index]
  target = "integrations/${aws_apigatewayv2_integration.api_integration.id}"
}

resource "aws_cloudwatch_log_group" "apigateway_log_group" {

  count = var.trigger.apigateway != null ? 1 : 0
  name = "/aws/api_gw/${aws_apigatewayv2_api.api.name}"
  retention_in_days = var.log_retention
}

resource "aws_lambda_permission" "api_gw" {

  count = var.trigger.apigateway != null ? 1 : 0
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
