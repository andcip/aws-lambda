
terraform {
  experiments = [module_variable_optional_attrs]
}

variable "lambda_name" {
  type = string
}

variable "lambda_runtime" {
  type = string
}
variable "lambda_handler" {
  type = string
}
variable "exclude_files" {
  default = []
  type    = list(string)
}

variable "source_dir" {
  type    = string
  default = "src"
}

variable "architecture" {
  type    = string
  default = "x86_64"

  validation {
    condition     = var.architecture == "x86_64" ||  var.architecture == "arm64"
    error_message = "Invalid architecture, allowed values x86_64 or arm64."
  }
}

variable "tags" {
  type    = object({})
  default = {}
}

variable "memory_size" {
  default = 128
  type    = number
  validation {
    condition     = var.memory_size == 128 || var.memory_size == 256 || var.memory_size == 512 || var.memory_size == 1024
    error_message = "Invalid memory size, allowed values are 128, 256, 512, 1024."
  }
}
variable "timeout" {
  default = 5
  type    = number
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "trigger" {
  default = null
  type    = object({
    s3 : optional(object({
      bucket : string,
      events : list(string),
      filter_prefix : string,
      filter_suffix : string
    }))
    apigateway : optional(object({
      type : string,
      existing_api_id: optional(string)
      disable_test_endpoint: optional(bool)
      cors_configuration: optional(object({
        allow_headers : set(string)
        allow_method : set(string)
        allow_origins: set(string)
        max_age: number
      }))
      authorizer: optional(object({
        name: string,
        identity_source: string,
        jwt: optional(object({
          aud: list(string),
          issuer: string
        }))
      }))
      routes : list(object({
        path : string,
        method : string,
        authorizer: optional(bool)
      }))
    }))
    #TODO alb trigger objejct
    alb : optional(string)

  })

}

variable "tracing_mode" {
  type    = string
  default = null
  validation {
    condition     = var.tracing_mode == null || var.tracing_mode == "Active" || var.tracing_mode == "PassThrough"
    error_message = "Allowed values are Active and PassThrough."
  }
}

variable "log_retention" {
  type    = number
  default = 90
}

variable "stage_name" {
  type    = string
  default = "api"
}

variable "iam_policies" {
  type    = list(object({
    actions   = list(string),
    principal = string,
    resource  = string
  }))
  default = []

}

variable "vpc_mode" {
  type    = object({
    id : string,
    subnet_ids : list(string)
  })
  default = null
}
