terraform {
  backend "s3" {
    bucket         = "s3-for-state-wiz" # REPLACE THIS
    key            = "wiz-exercise/global/s3/terraform.tfstate"
    region         = "us-east-1"                               # REPLACE WITH YOUR CHOSEN REGION
    encrypt        = true
    dynamodb_table = "s3-for-state-wiz"  # REPLACE THIS
  }
}

