provider "aws" {
  region = "us-east-1"
}

# API Gateway
resource "aws_api_gateway_rest_api" "my_api" {
  name = "MyServerlessAPI"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.my_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "my_api_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda]
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  stage_name  = "prod"
}

# Lambda Function
resource "aws_lambda_function" "my_lambda" {
  function_name = "MyLambdaFunction"
  handler       = "com.example.MyLambdaHandler::handleRequest"
  runtime       = "java17"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "../target/my-lambda-function-1.0-SNAPSHOT.jar"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

# DynamoDB Table
resource "aws_dynamodb_table" "my_table" {
  name         = "MyTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-serverless-bucket"
}

resource "aws_s3_bucket_acl" "my_bucket_acl" {
  bucket = aws_s3_bucket.my_bucket.id
  acl    = "private"
}

# SNS Topic
resource "aws_sns_topic" "my_topic" {
  name = "MyTopic"
}

# SQS Queue
resource "aws_sqs_queue" "my_queue" {
  name = "MyQueue"
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "my_log_group" {
  name = "/aws/lambda/MyLambdaFunction"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Managed Policy for Basic Lambda Execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom IAM Policy for Lambda to Access Other AWS Services
resource "aws_iam_policy" "lambda_custom_policy" {
  name        = "LambdaCustomPolicy"
  description = "Custom policy for Lambda to access AWS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-serverless-bucket",
          "arn:aws:s3:::my-serverless-bucket/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:*:table/MyTable"
      },
      {
        Effect   = "Allow"
        Action   = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.my_topic.arn
      },
      {
        Effect   = "Allow"
        Action   = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.my_queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_custom_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_custom_policy.arn
}

# Outputs
output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.my_api.id}.execute-api.us-east-1.amazonaws.com/prod"
}