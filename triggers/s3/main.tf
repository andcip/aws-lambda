data "aws_s3_bucket" "trigger_source_bucket" {
  count = var.trigger != null ? 1 : 0
  bucket = var.trigger.bucket
}

resource "aws_s3_bucket_notification" "s3_bucket_action_trigger" {
  count = var.trigger != null ? 1 : 0

  bucket = data.aws_s3_bucket.trigger_source_bucket.id
  lambda_function {
    lambda_function_arn = var.lambda_function_arn
    events = var.trigger.events
    filter_prefix = var.trigger.filter_prefix
    filter_suffix = var.trigger.filter_suffix
  }
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.trigger_source_bucket.arn
}
