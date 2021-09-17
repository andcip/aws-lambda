
resource "aws_s3_bucket_notification" "s3_bucket_action_trigger" {
  count = var.trigger.s3 != null ? 1 : 0

  bucket = var.trigger.s3.bucket
  lambda_function {
    lambda_function_arn = var.lambda_function_arn
    events = var.trigger.s3.events
    filter_prefix = var.trigger.s3.filter_prefix
    filter_suffix = var.trigger.s3.filter_suffix
  }
}
