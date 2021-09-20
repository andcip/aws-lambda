
resource "aws_s3_bucket_notification" "s3_bucket_action_trigger" {
  count = var.trigger != null ? 1 : 0

  bucket = var.trigger.bucket
  lambda_function {
    lambda_function_arn = var.lambda_function_arn
    events = var.trigger.events
    filter_prefix = var.trigger.filter_prefix
    filter_suffix = var.trigger.filter_suffix
  }
}
