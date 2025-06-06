# ./modules/ec2_mongodb/main.tf

# Data source to find an AMI if mongodb_ami_id is not provided.
# This example looks for a generic Amazon Linux 2 AMI.
# You MUST adjust this or provide a specific var.mongodb_ami_id for an OUTDATED version.

# Finds the latest Amazon Linux 2 AMI if no AMI ID is explicitly provided.

data "aws_ami" "selected_ami" {
  count = var.mongodb_ami_id == "" ? 1 : 0 # Only run if mongodb_ami_id is not set

  most_recent = true
  owners      = ["amazon"] # For Amazon Linux AMIs

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Example: Amazon Linux 2
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


# Launches an EC2 instance for MongoDB using the provided or looked-up AMI, with configuration done via user_data.

resource "aws_instance" "mongodb_server" {
  ami                         = var.mongodb_ami_id != "" ? var.mongodb_ami_id : data.aws_ami.selected_ami[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.vpc_security_group_ids
  iam_instance_profile        = var.iam_instance_profile_name
  key_name = "id_rsa"
  associate_public_ip_address = true # Since it's in a public subnet for SSH access as per exercise

# Runs a shell script the first time the machine boots.

  # This script installs MongoDB, sets up a database user, configures backups to S3, and more.
  # This creates a virtual machine in AWS that installs and runs MongoDB. 
  # It automatically sets everything up when it boots: username, password, configuration, and backup to S3. 
  # If anything in the setup script changes later, Terraform will recreate the machine to keep it up to date.".
  
  
user_data = templatefile("${path.module}/user_data/install_mongodb.sh", { 

    DB_USERNAME         = var.db_username 
    DB_PASSWORD         = var.db_password
    S3_BACKUP_BUCKET    = var.s3_backup_bucket_name
    AWS_REGION          = var.aws_region
    UBUNTU_CODENAME     = "bionic"
    MONGOD_CONF_PATH    = "/etc/mongod.conf"
    
  })

 # Replaces EC2 instance if the user_data script content changes — ensures config stays fresh.

user_data_replace_on_change = true 
  tags = {
    Name = "${var.project_name}-mongodb-server"
  }
}

