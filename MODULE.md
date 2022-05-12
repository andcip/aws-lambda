<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 3.62.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.1.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_trigger_http"></a> [trigger\_http](#module\_trigger\_http) | ./triggers/http | n/a |
| <a name="module_trigger_rest"></a> [trigger\_rest](#module\_trigger\_rest) | ./triggers/rest | n/a |
| <a name="module_trigger_s3"></a> [trigger\_s3](#module\_trigger\_s3) | ./triggers/s3 | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.lambda_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.errors_count_alarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_policy.function_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.function_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.function_logging_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.function_policy_attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.vpc_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.xray_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_s3_bucket.lambda_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_object.lambda_zip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object) | resource |
| [aws_security_group.lambda_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [random_integer.bucket_salt](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) | resource |
| [archive_file.files](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy.vpc_access_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy.xray_enable_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_topic"></a> [alarm\_topic](#input\_alarm\_topic) | Topic for alarms notification | `string` | `null` | no |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | The platform architecture, valid values are x86\_64 and arm64. Default x86\_64. | `string` | `"x86_64"` | no |
| <a name="input_concurrent_execution"></a> [concurrent\_execution](#input\_concurrent\_execution) | Amount of reserved concurrent executions for this lambda function. A value of 0 disables lambda from being triggered and -1 removes any concurrency limitations. Defaults to Unreserved Concurrency Limits -1 | `number` | `-1` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Map of environment variables that are accessible from the function code during execution. | `map(string)` | `{}` | no |
| <a name="input_exclude_files"></a> [exclude\_files](#input\_exclude\_files) | Files list to exclude from the zip | `list(string)` | `[]` | no |
| <a name="input_iam_policies"></a> [iam\_policies](#input\_iam\_policies) | List of IAM policy for the lambda | <pre>list(object({<br>    actions   = list(string),<br>    resources = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_lambda_handler"></a> [lambda\_handler](#input\_lambda\_handler) | The entrypoint of the lambda application, with the fully qualify name of the method, for example src/main.handler. | `string` | n/a | yes |
| <a name="input_lambda_name"></a> [lambda\_name](#input\_lambda\_name) | The lambda name and anything else. | `string` | n/a | yes |
| <a name="input_lambda_runtime"></a> [lambda\_runtime](#input\_lambda\_runtime) | The lambda runtime engine, see @https://docs.aws.amazon.com/lambda/latest/dg/API_CreateFunction.html#SSS-CreateFunction-request-Runtime. | `string` | n/a | yes |
| <a name="input_log_retention"></a> [log\_retention](#input\_log\_retention) | The cloudwatch log retention. Default 90. | `number` | `90` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Amount of memory in MB your Lambda Function can use at runtime. Valid values are 128, 256, 512, 1024, 2048. Defaults to 128. | `number` | `128` | no |
| <a name="input_source_dir"></a> [source\_dir](#input\_source\_dir) | Source of the lambda code, it can be a simple directory or an already zipped one. Default src. | `string` | `"src"` | no |
| <a name="input_stage_name"></a> [stage\_name](#input\_stage\_name) | n/a | `string` | `"api"` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Amount of time your Lambda Function has to run in seconds. Defaults to 5. | `number` | `5` | no |
| <a name="input_tracing_mode"></a> [tracing\_mode](#input\_tracing\_mode) | The XRAY service integration. It can be Active or PassThrough. Default disabled. | `string` | `null` | no |
| <a name="input_trigger"></a> [trigger](#input\_trigger) | Trigger object variable. It can specify sqs, apigateway with route and authorizer, sqs or s3 trigger. | <pre>object({<br>    s3 : optional(object({<br>      bucket : string,<br>      events : list(string),<br>      filter_prefix : string,<br>      filter_suffix : string<br>    }))<br>    apigateway : optional(object({<br>      type : string,<br>      existing_api_id : optional(string)<br>      disable_test_endpoint : optional(bool)<br>      resource_policy : optional(string)<br>      cors_configuration : optional(object({<br>        allow_headers : set(string)<br>        allow_method : set(string)<br>        allow_origins : set(string)<br>        max_age : number<br>      }))<br>      authorizer : optional(object({<br>        name : string,<br>        identity_source : string,<br>        jwt : optional(object({<br>          aud : list(string),<br>          issuer : string<br>        }))<br>      }))<br>      routes : list(object({<br>        path : string,<br>        method : string,<br>        authorizer : optional(bool)<br>      }))<br>    }))<br>    #TODO alb trigger objejct<br>    alb : optional(string)<br><br>  })</pre> | `null` | no |
| <a name="input_vpc_mode"></a> [vpc\_mode](#input\_vpc\_mode) | Use it to enable Lambda to run in VPC. Default disabled. | <pre>object({<br>    id : string,<br>    subnet_ids : list(string)<br>    security_group = optional(object({<br>      ingress = optional(list(object({<br>        from_port       = number<br>        to_port         = number<br>        protocol        = string<br>        cidr_blocks     = optional(list(string))<br>        security_groups = optional(list(string))<br>      })))<br>      egress = optional(list(object({<br>        from_port       = number<br>        to_port         = number<br>        protocol        = string<br>        cidr_blocks     = optional(list(string))<br>        security_groups = optional(list(string))<br>      })))<br>    }))<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda"></a> [lambda](#output\_lambda) | n/a |
<!-- END_TF_DOCS -->