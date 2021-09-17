variable "lambda_function_arn" {
  type = string
}

variable "trigger" {
  type = object({
    bucket: string,
    events: list(string),
    filter_prefix: string,
    filter_suffix: string
  })

  validation {
    condition = var.trigger == null || var.trigger.bucket != null && length(var.trigger.events) > 0
    error_message = "Invalid trigger variable, bucket and events variables must be not null"
  }
}
