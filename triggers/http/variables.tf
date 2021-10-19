terraform {
  experiments = [module_variable_optional_attrs]
}

variable "trigger" {
  type = object({
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

variable "environment" {
  type = string
}

variable "log_retention" {
  type    = number
  default = 90
}

variable "timeout_milliseconds" {
  type    = number
  default = 5000
  validation {
    condition     = var.timeout_milliseconds <= 30000 && var.timeout_milliseconds >= 50
    error_message = "Timeout variable must be between 50 and 30000."
  }
}
