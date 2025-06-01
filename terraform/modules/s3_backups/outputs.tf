output "bucket_name_output" {
  description = "The name of the S3 backup bucket"
  value       = aws_s3_bucket.backup_bucket.bucket
}

output "bucket_arn_output" {
  description = "The ARN of the S3 backup bucket"
  value       = aws_s3_bucket.backup_bucket.arn
}

