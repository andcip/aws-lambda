terraform {
  experiments = [module_variable_optional_attrs]
}

variable "lambda_name" {
  type        = string
  description = "The lambda name and anything else."
}

variable "lambda_runtime" {
  type        = string
  description = "The lambda runtime engine, see @https://docs.aws.amazon.com/lambda/latest/dg/API_CreateFunction.html#SSS-CreateFunction-request-Runtime."
}

variable "lambda_handler" {
  type        = string
  description = "The entrypoint of the lambda application, with the fully qualify name of the method, for example src/main.handler."
}

variable "exclude_files" {
  default     = []
  type        = list(string)
  description = "Files list to exclude from the zip"
}

variable "source_dir" {
  type        = string
  default     = "src"
  description = "Source of the lambda code, it can be a simple directory or an already zipped one. Default src."
}

variable "architecture" {
  type        = string
  default     = "x86_64"
  description = "The platform architecture, valid values are x86_64 and arm64. Default x86_64."

  validation {
    condition     = var.architecture == "x86_64" ||  var.architecture == "arm64"
    error_message = "Invalid architecture, allowed values x86_64 or arm64."
  }
}

variable "concurrent_execution" {
  type = number
  default = -1
  description = "Amount of reserved concurrent executions for this lambda function. A value of 0 disables lambda from being triggered and -1 removes any concurrency limitations. Defaults to Unreserved Concurrency Limits -1"
}

variable "memory_size" {
  default     = 128
  type        = number
  description = " Amount of memory in MB your Lambda Function can use at runtime. Valid values are 128, 256, 512, 1024. Defaults to 128."
  validation {
    condition     = var.memory_size == 128 || var.memory_size == 256 || var.memory_size == 512 || var.memory_size == 1024
    error_message = "Invalid memory size, allowed values are 128, 256, 512, 1024."
  }
}
variable "timeout" {
  default     = 5
  type        = number
  description = "Amount of time your Lambda Function has to run in seconds. Defaults to 5."
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Map of environment variables that are accessible from the function code during execution."
}

variable "trigger" {

  type = object({
    s3 : optional(object({
      bucket : string,
      events : list(string),
      filter_prefix : string,
      filter_suffix : string
    }))
    apigateway : optional(object({
      type : string,
      existing_api_id : optional(string)
      disable_test_endpoint : optional(bool)
      cors_configuration : optional(object({
        allow_headers : set(string)
        allow_method : set(string)
        allow_origins : set(string)
        max_age : number
      }))
      authorizer : optional(object({
        name : string,
        identity_source : string,
        jwt : optional(object({
          aud : list(string),
          issuer : string
        }))
      }))
      routes : list(object({
        path : string,
        method : string,
        authorizer : optional(bool)
      }))
    }))
    #TODO alb trigger objejct
    alb : optional(string)

  })

  default = null

  description = "Trigger object variable. It can specify sqs, apigateway with route and authorizer, sqs or s3 trigger."

}

variable "tracing_mode" {
  type        = string
  default     = null
  description = "The XRAY service integration. It can be Active or PassThrough. Default disabled."
  validation {
    condition     = var.tracing_mode == null || var.tracing_mode == "Active" || var.tracing_mode == "PassThrough"
    error_message = "Allowed values are Active and PassThrough."
  }
}

variable "log_retention" {
  type        = number
  default     = 90
  description = "The cloudwatch log retention. Default 90."
}

variable "stage_name" {
  type    = string
  default = "api"
}

variable "iam_policies" {
  type = list(object({
    actions   = list(string),
    principal = string,
    resource  = string
  }))

  default     = []
  description = "List of IAM policy for the lambda"
}

variable "vpc_mode" {
  type        = object({
    id : string,
    subnet_ids : list(string)
    security_group = optional(object({
      ingress = optional(list(object({
        from_port       = number
        to_port         = number
        protocol        = string
        cidr_blocks     = optional(list(string))
        security_groups = optional(list(string))
      })))
      egress = optional(list(object({
        from_port       = number
        to_port         = number
        protocol        = string
        cidr_blocks     = optional(list(string))
        security_groups = optional(list(string))
      })))
    }))
  })
  default     = null
  description = "Use it to enable Lambda to run in VPC. Default disabled."
}
