output "s3_bucket_name" {
  description = "Created S3 bucket name"
  value       = aws_s3_bucket.this.id
}

output "s3_bucket_arn" {
  description = "Created S3 bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "s3_bucket_region" {
  description = "AWS Region"
  value       = "us-east-1"
}
