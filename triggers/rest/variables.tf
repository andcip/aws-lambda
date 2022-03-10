terraform {
  experiments = [module_variable_optional_attrs]
}

variable "trigger" {
  type = object({
    existing_api_id: optional(string)
    disable_test_endpoint: optional(bool)
    cors_configuration: optional(object({
      allow_headers : set(string)
      allow_method : set(string)
      allow_origins: set(string)
      max_age: number
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
      authorizer: optional(bool)
    }))
  })
  validation {
    condition     = length(var.trigger.routes) > 0
    error_message = "Invalid trigger variable, routes length must be > 0."
  }
}

variable "lambda_function_invoke_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "stage_name" {
  type = string
}

variable "log_retention" {
  type    = number
  default = 90
}

variable "tracing_enabled" {
  type = bool
  default = false
  description = "Enable XRAY integration in Api Gateway stage"
}

variable "timeout_milliseconds" {
  type    = number
  default = 5000
  validation {
    condition     = var.timeout_milliseconds <= 30000 && var.timeout_milliseconds >= 50
    error_message = "Timeout variable must be between 50 and 30000."
  }
}
