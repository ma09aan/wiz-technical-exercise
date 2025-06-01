# terraform {
#   backend "s3" {
#     bucket         = "your-unique-terraform-state-bucket-name" # REPLACE THIS
#     key            = "wiz-exercise/global/s3/terraform.tfstate"
#     region         = "us-east-1"                               # REPLACE WITH YOUR CHOSEN REGION
#     encrypt        = true
#     dynamodb_table = "your-unique-terraform-state-lock-table"  # REPLACE THIS
#   }
# }

