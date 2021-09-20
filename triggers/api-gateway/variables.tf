variable "trigger" {
  type = object({
    routes: list(string)
  })

  validation {
    condition = var.trigger == null || var.trigger.routes != null && length(var.trigger.routes) > 0
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
  type = number
  default = 90
}

variable "timeout_milliseconds" {
  type = number
  default = 5000
   validation {
     condition = var.timeout_milliseconds <= 30000 && var.timeout_milliseconds >= 50
     error_message = "Timeout variable must be between 50 and 30000."
   }
}
