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
  type = list(string)
}

variable "tags" {
  type = object({})
  default = {}
}

variable "memory_size" {
  default = 128
  type = number
  validation {
    condition = var.memory_size == 128 || var.memory_size == 256 || var.memory_size == 512 || var.memory_size == 1024
    error_message = "Invalid memory size, allowed values are 128, 256, 512, 1024"
  }
}
variable "timeout" {
  default = 5
  type = number
}

variable "environment_variables" {
  type = map(string)
}

variable "trigger" {
  type = object({
    s3: object({
      bucket: string,
      events: list(string),
      filter_prefix: string,
      filter_suffix: string
    })
    #TODO apigateway triggerobejct
    apigateway: object({
      routes: list(string)
    })
    #TODO alb trigger objejct
    alb: string

  })
  validation {
    condition = var.trigger == null || var.trigger.s3 != null || var.trigger.apigateway != null || var.trigger.alb != null
    error_message = "Invalid trigger variable, s3 or apigateway pr alb have to be not null"
  }
}

variable "tracing_mode" {
  type = string
  validation {
    condition = var.tracing_mode == null || var.tracing_mode == "Active" || var.tracing_mode == "PassThrough"
    error_message = "Invalid tracing mode, allowed values are Active and PassThrough"
  }
}

variable "log_retention" {
  type = number
  default = 90
}

variable "environment" {
  type = string
  default = "develop"
}
