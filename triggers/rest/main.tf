data "aws_region" "current" {}
data "aws_caller_identity" "account" {}

locals {

  api_routes = [ for route in var.trigger.routes: {
    path: route.path
    parameter: length(regexall( "{", route.path )) > 0 ? substr( route.path , index(split("", route.path), "{") +1, index(split("", route.path), "}") - index(split("", route.path), "{") -1) : ""
    method: lower(route.method) ==  "any" ? "x-amazon-apigateway-any-method" : lower(route.method)
  }]

  openAPI_spec = {
    for route in local.api_routes : route.path => {
        "${route.method}" = {
        x-amazon-apigateway-integration = {
          type       = "aws_proxy"
          httpMethod = "POST"
          uri        = var.lambda_function_invoke_arn
          timeoutInMillis = var.timeout_milliseconds
          payloadFormatVersion =  "2.0"
        }
      }
    }
  }
}

##TODO add authorizer, api key, update module variable (how to attach to existing api id?)
resource "aws_api_gateway_rest_api" "api" {
  name = "${var.lambda_function_name}-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
  body = jsonencode({
    openapi = "3.0.1"
    paths   = local.openAPI_spec
  })
  #   body = templatefile("${path.module}/openapi.tftpl", {routes: local.api_routes, lambda_invoke_arn: var.lambda_function_invoke_arn})


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
  xray_tracing_enabled = var.tracing_enabled

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
