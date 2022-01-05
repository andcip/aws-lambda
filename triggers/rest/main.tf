locals {

  api_routes = [for route in var.trigger.routes: {
    path: route.path
    parameter: regexall( "{", route.path ) ? substr( route.path , index(split("", route.path), "{") +1, index(split("", route.path), "}") - index(split("", route.path), "{") -1) : ""
    method: route.method
  }]

}
##TODO add authorizer, api key, update module variable (how to attach to existing api id?)
resource "aws_api_gateway_rest_api" "api" {
  name = "${var.lambda_function_name}-api"

  body = templatefile("${path.module}/openapi.tftpl", {routes: local.api_routes, lambda_invoke_arn: var.lambda_function_invoke_arn})

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "deployment" {

  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers    = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {

  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.stage_name
  deployment_id = aws_api_gateway_deployment.deployment.id

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



resource "aws_cloudwatch_log_group" "apigateway_log_group" {

  name              = "/aws/api_gw/${aws_api_gateway_rest_api.api.name}"
  retention_in_days = var.log_retention
}

resource "aws_lambda_permission" "api_gw_lambda_invoke_permission" {

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
