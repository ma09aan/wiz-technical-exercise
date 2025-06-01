# ./modules/s3_backups/main.tf
resource "aws_s3_bucket" "backup_bucket" {
  bucket = var.bucket_name
  # ACLs are generally discouraged, prefer bucket policies.
  # For this exercise, to make it "public readable", an ACL or policy is needed.
  # acl    = "public-read" # !! INTENTIONAL WEAKNESS if objects also public !!
  tags = {
    Name = "${var.project_name}-db-backups"
  }
}

# !! INTENTIONAL WEAKNESS: Allow public listing and reading of objects !!
resource "aws_s3_bucket_policy" "backup_bucket_public_policy" {
  bucket = aws_s3_bucket.backup_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "PublicReadForGetBucketObjects",
        Effect = "Allow",
        Principal = "*", # Makes objects publicly readable
        Action = [
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.backup_bucket.arn}/*" # All objects in the bucket
      },
      {
        Sid    = "PublicReadForListBucket",
        Effect = "Allow",
        Principal = "*", # Makes bucket contents listable by public
        Action = [
          "s3:ListBucket"
        ],
        Resource = aws_s3_bucket.backup_bucket.arn
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "backup_bucket_access_block" {
  bucket = aws_s3_bucket.backup_bucket.id

  # !! INTENTIONAL WEAKNESS: Set these to false to allow public access as per policy !!
  block_public_acls       = false # If using ACLs, this needs to be false
  block_public_policy     = false # Allows public bucket policies
  ignore_public_acls      = false # If using ACLs, this needs to be false
  restrict_public_buckets = false # Allows public access if policy/ACLs permit
}

# Required if you want to set bucket ACLs or if objects are written by other accounts/services
# and you want the bucket owner to have full control.
# For simple public read via policy, this might not be strictly necessary but good practice.
resource "aws_s3_bucket_ownership_controls" "backup_bucket_ownership" {
  bucket = aws_s3_bucket.backup_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Apply bucket ACL if you chose that route (generally less preferred than policies)
# resource "aws_s3_bucket_acl" "backup_bucket_acl" {
#   depends_on = [aws_s3_bucket_ownership_controls.backup_bucket_ownership, aws_s3_bucket_public_access_block.backup_bucket_access_block]
#   bucket = aws_s3_bucket.backup_bucket.id
#   acl    = "public-read" # !! INTENTIONAL WEAKNESS !!
# }

