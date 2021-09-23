## API GATEWAY

resource "aws_apigatewayv2_api" "api" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "stage" {

  api_id      = aws_apigatewayv2_api.api[count.index].id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway_log_group[count.index].arn

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

  api_id               = aws_apigatewayv2_api.api[count.index].id
  integration_uri      = var.lambda_function_invoke_arn
  timeout_milliseconds = var.timeout_milliseconds
  integration_type     = "AWS_PROXY"
  integration_method   = "POST"
}

resource "aws_apigatewayv2_route" "api_route" {

  count     = length(var.trigger.routes)
  api_id    = aws_apigatewayv2_api.api[count.index].id
  route_key = var.trigger.routes[count.index]
  target    = "integrations/${aws_apigatewayv2_integration.api_integration[count.index].id}"
}

resource "aws_cloudwatch_log_group" "apigateway_log_group" {

  count             = var.trigger != null ? 1 : 0
  name              = "/aws/api_gw/${aws_apigatewayv2_api.api[count.index].name}"
  retention_in_days = var.log_retention
}

resource "aws_lambda_permission" "api_gw_lambda_invoke_permission" {

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api[count.index].execution_arn}/*/*"
}
