#!/bin/bash -xe
# User data script for MongoDB instance
# This script attempts to install MongoDB 4.4 as an "outdated" version.
# Ensure the AMI chosen (Debian/Ubuntu or RHEL/Amazon Linux based) has systemd.

# Variables passed from Terraform
DB_USERNAME="{{DB_USERNAME}}"
DB_PASSWORD="{{DB_PASSWORD}}"
S3_BACKUP_BUCKET="{{S3_BACKUP_BUCKET}}"
AWS_REGION="{{AWS_REGION}}"

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user_data script for MongoDB setup (v4 - robust auth setup)..."

# --- Helper function to check if a command exists ---
command_exists () {
    type "$1" &> /dev/null ;
}

# --- 1. Install MongoDB 4.4 ---
echo "Attempting to install MongoDB 4.4..."
# Determine OS and Package Manager
if command_exists apt-get ; then
    OS_FAMILY="debian"
elif command_exists yum ; then
    OS_FAMILY="rhel"
else
    echo "Unsupported package manager. Please adapt MongoDB installation for your chosen AMI."
    exit 1
fi

# Install MongoDB based on OS Family
if [ "$OS_FAMILY" = "debian" ]; then
    echo "Detected apt-get (Debian/Ubuntu based system)."
    echo "Configuring MongoDB 4.4 repository..."
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    UBUNTU_CODENAME="bionic" # Default for older LTS, adjust if your AMI is different & compatible
    if [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        if [ "$DISTRIB_ID" == "Ubuntu" ]; then
            if [[ "$DISTRIB_CODENAME" == "xenial" || "$DISTRIB_CODENAME" == "bionic" || "$DISTRIB_CODENAME" == "focal" ]]; then
                UBUNTU_CODENAME=$DISTRIB_CODENAME
            fi
        fi
    fi
    echo "Using Ubuntu codename '$UBUNTU_CODENAME' for MongoDB 4.4 repository."
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${UBUNTU_CODENAME}/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    sudo apt-get update -y
    echo "Installing MongoDB 4.4 (mongodb-org)..."
    # Try to install specific patch version of 4.4 if generic fails or to be more precise
    sudo apt-get install -y --allow-unauthenticated mongodb-org=4.4.29 mongodb-org-server=4.4.29 mongodb-org-shell=4.4.29 mongodb-org-mongos=4.4.29 mongodb-org-tools=4.4.29 || sudo apt-get install -y --allow-unauthenticated mongodb-org
    if ! command_exists mongod; then echo "FAIL: mongod not found after apt-get install."; exit 1; fi
    echo "SUCCESS: mongodb-org seems installed via apt-get."

elif [ "$OS_FAMILY" = "rhel" ]; then
    echo "Detected yum (RHEL/CentOS/Amazon Linux based system)."
    echo "Configuring MongoDB 4.4 repository..."
    sudo tee /etc/yum.repos.d/mongodb-org-4.4.repo << EOL
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
EOL
    echo "Waiting for yum locks..."
    sudo yum-complete-transaction --cleanup-only || true 
    retry_count=0; max_retries=24 
    while sudo fuser /var/run/yum.pid >/dev/null 2>&1 && [ "$retry_count" -lt "$max_retries" ]; do
        echo "Yum locked, waiting 5s... (Attempt: $((retry_count+1))/$max_retries)"
        sleep 5; retry_count=$((retry_count+1))
    done
    if sudo fuser /var/run/yum.pid >/dev/null 2>&1; then echo "FAIL: Yum lock persisted."; exit 1; fi
    echo "Proceeding with yum update..."
    sudo yum update -y
    echo "Installing MongoDB 4.4 (mongodb-org)..."
    sudo yum install -y mongodb-org-4.4.29 mongodb-org-server-4.4.29 mongodb-org-shell-4.4.29 mongodb-org-mongos-4.4.29 mongodb-org-tools-4.4.29 || sudo yum install -y mongodb-org
    if ! command_exists mongod; then echo "FAIL: mongod not found after yum install."; exit 1; fi
    echo "SUCCESS: mongodb-org seems installed via yum."
fi

# --- 2. Initial MongoDB Configuration (No Auth) & First User Creation ---
MONGO_SERVICE_NAME="mongod"
MONGOD_CONF_PATH="/etc/mongod.conf"
if [ ! -f $MONGOD_CONF_PATH ] && [ -f "/etc/mongodb.conf" ]; then MONGOD_CONF_PATH="/etc/mongodb.conf"; fi

if [ ! -f $MONGOD_CONF_PATH ]; then
    echo "FAIL: MongoDB configuration file ($MONGOD_CONF_PATH) not found after installation."
    exit 1
fi

echo "STAGE 1: Preparing mongod.conf for NO AUTHENTICATION and starting mongod."
sudo cp "$MONGOD_CONF_PATH" "${MONGOD_CONF_PATH}.orig-$(date +%s)" # Backup with timestamp

# Force bindIp to 127.0.0.1 and remove any 'security.authorization: enabled' for initial user creation
echo "Modifying $MONGOD_CONF_PATH for no-auth startup..."
# Remove any existing top-level bindIp
sudo sed -i '/^\s*bindIp:/d' "$MONGOD_CONF_PATH" 
# Ensure net section and set bindIp to 127.0.0.1
if ! grep -q "^\s*net:" "$MONGOD_CONF_PATH"; then
    echo -e "\nnet:\n  port: 27017\n  bindIp: 127.0.0.1" | sudo tee -a "$MONGOD_CONF_PATH"
else
    # Ensure port is set
    if ! (grep -A 1 "^\s*net:" "$MONGOD_CONF_PATH" | grep -q "^\s*port:"); then
         sudo sed -i '/^\s*net:/a \ \ port: 27017' "$MONGOD_CONF_PATH"
    fi
    # Ensure bindIp is set to 127.0.0.1 under net
    if ! (grep -A 2 "^\s*net:" "$MONGOD_CONF_PATH" | grep -q "^\s*bindIp:"); then
        sudo sed -i '/^\s*net:/a \ \ bindIp: 127.0.0.1' "$MONGOD_CONF_PATH"
    else 
        sudo sed -i '/^\s*net:/,/^[^ ]/s/^\(\s*bindIp:\s*\).*/\1127.0.0.1/' "$MONGOD_CONF_PATH"
    fi
fi
# Aggressively remove/comment out 'authorization: enabled' under 'security:'
if grep -q "^\s*security:" "$MONGOD_CONF_PATH"; then
    echo "Found security section, ensuring authorization is disabled/removed for now..."
    # Delete the line 'authorization: enabled' if it exists under security
    sudo sed -i '/^\s*security:/,/^[^ ]/d' "$MONGOD_CONF_PATH"
    # If 'security:' block becomes empty or only has comments, that's fine for no-auth.
fi
echo "DEBUG: $MONGOD_CONF_PATH content BEFORE starting for user creation:"
sudo cat "$MONGOD_CONF_PATH"

echo "Stopping $MONGO_SERVICE_NAME (if running from previous attempt)..."
sudo systemctl stop $MONGO_SERVICE_NAME || echo "$MONGO_SERVICE_NAME was not running."
sleep 5

echo "Starting MongoDB service for initial user creation (NO AUTH should be active)..."
sudo systemctl daemon-reload
sudo systemctl enable $MONGO_SERVICE_NAME # Make sure it's enabled to start on boot later
sudo systemctl start $MONGO_SERVICE_NAME
sleep 20 # Increased wait for mongod to fully start
sudo systemctl status $MONGO_SERVICE_NAME --no-pager
if ! sudo systemctl is-active --quiet $MONGO_SERVICE_NAME; then
    echo "FAIL: MongoDB ($MONGO_SERVICE_NAME) failed to start for user creation (no-auth stage)."
    sudo journalctl -u $MONGO_SERVICE_NAME -n 100 --no-pager
    exit 1
fi
echo "MongoDB service started for user creation."

# Create the admin user
if command_exists mongo; then
    echo "Creating MongoDB admin user '${DB_USERNAME}'..."
    # Attempt to connect to localhost where mongod should be running without auth
    mongo admin --host localhost --eval "db.createUser({user: \"${DB_USERNAME}\", pwd: \"${DB_PASSWORD}\", roles: [{role: \"userAdminAnyDatabase\", db: \"admin\"}, {role: \"readWriteAnyDatabase\", db: \"admin\"}]})"
    
    if [ $? -ne 0 ]; then
        echo "FAIL: Failed to create MongoDB admin user. Error code $?."
        echo "This means mongod still required authentication or another error occurred during user creation."
        sudo journalctl -u $MONGO_SERVICE_NAME -n 50 --no-pager # Check mongod logs
        exit 1
    fi
    echo "SUCCESS: MongoDB admin user '${DB_USERNAME}' created."
else
    echo "FAIL: Mongo shell not found. Cannot create user."
    exit 1
fi

# Stop MongoDB before final configuration
echo "Stopping MongoDB to apply final (auth-enabled) configuration..."
sudo systemctl stop $MONGO_SERVICE_NAME
sleep 5

# --- 3. Final MongoDB Configuration (Enable Auth, Bind to 0.0.0.0) ---
# --- 3. Final MongoDB Configuration (Enable Auth, Bind to 0.0.0.0) ---
echo "STAGE 2: Applying final MongoDB configuration (authentication enabled, bindIp 0.0.0.0)..."

# Backup the current configuration
sudo cp "$MONGOD_CONF_PATH" "${MONGOD_CONF_PATH}.final-$(date +%s)"

# Remove any existing bindIp entries under net
sudo sed -i '/^\s*bindIp:/d' "$MONGOD_CONF_PATH"

# Ensure 'net' section exists and update bindIp to 0.0.0.0
if ! grep -q "^\s*net:" "$MONGOD_CONF_PATH"; then
    echo -e "\nnet:\n  port: 27017\n  bindIp: 0.0.0.0" | sudo tee -a "$MONGOD_CONF_PATH"
else
    if ! (grep -A 2 "^\s*net:" "$MONGOD_CONF_PATH" | grep -q "^\s*bindIp:"); then
        sudo sed -i '/^\s*net:/a \ \ bindIp: 0.0.0.0' "$MONGOD_CONF_PATH"
    else
        sudo sed -i '/^\s*net:/,/^[^ ]/s/^\(\s*bindIp:\s*\).*/\10.0.0.0/' "$MONGOD_CONF_PATH"
    fi
fi

# Add or update 'security.authorization: enabled'
if ! grep -q "^\s*security:" "$MONGOD_CONF_PATH"; then
    echo -e "\nsecurity:\n  authorization: enabled" | sudo tee -a "$MONGOD_CONF_PATH"
else
    # Remove the full 'security' block and rewrite it cleanly
    sudo sed -i '/^\s*security:/,/^[^ ]/d' "$MONGOD_CONF_PATH"
    echo -e "\nsecurity:\n  authorization: enabled" | sudo tee -a "$MONGOD_CONF_PATH"
fi

echo "DEBUG: $MONGOD_CONF_PATH content AFTER final modification:"
sudo cat "$MONGOD_CONF_PATH"

echo "Restarting MongoDB with final configuration..."
sudo systemctl daemon-reexec
sudo systemctl restart $MONGO_SERVICE_NAME
sleep 10

if sudo systemctl is-active --quiet $MONGO_SERVICE_NAME; then
    echo "SUCCESS: MongoDB is running with authentication and bindIp 0.0.0.0"
else
    echo "FAIL: MongoDB failed to restart with final configuration."
    sudo journalctl -u $MONGO_SERVICE_NAME -n 50 --no-pager
    exit 1
fi


# --- 4. Set up Automated Database Backups to S3 ---
echo "Setting up S3 backups..."
if ! command_exists aws ; then
    echo "Installing AWS CLI..."
    if [ "$OS_FAMILY" = "debian" ]; then
        sudo apt-get update -y && sudo apt-get install -y awscli
    elif [ "$OS_FAMILY" = "rhel" ]; then
        sudo yum install -y awscli
    fi
fi

if ! command_exists aws ; then
    echo "FAIL: AWS CLI not found. S3 backups will fail."
else
    cat <<EOT > /usr/local/bin/mongodb_backup.sh
#!/bin/bash
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/mongodb_backups"
S3_BUCKET_PATH="s3://${S3_BACKUP_BUCKET}/backups" 
DB_USER_PARAM="${DB_USERNAME}"
DB_PASS_PARAM="${DB_PASSWORD}"
AWS_CLI_REGION="${AWS_REGION}"

mkdir -p \$BACKUP_DIR
echo "Starting mongodump at \$(date) for user \$DB_USER_PARAM..."
mongodump --username="\$DB_USER_PARAM" --password="\$DB_PASS_PARAM" --authenticationDatabase="admin" --out="\$BACKUP_DIR/\$TIMESTAMP" --forceTableScan

if [ -d "\$BACKUP_DIR/\$TIMESTAMP" ] && [ "\$(ls -A \$BACKUP_DIR/\$TIMESTAMP 2>/dev/null)" ]; then
    echo "mongodump successful. Archiving..."
    tar -czf \$BACKUP_DIR/mongodb_backup_\$TIMESTAMP.tar.gz -C \$BACKUP_DIR/\$TIMESTAMP .
    
    echo "Uploading to S3: \$S3_BUCKET_PATH/mongodb_backup_\$TIMESTAMP.tar.gz"
    aws s3 cp \$BACKUP_DIR/mongodb_backup_\$TIMESTAMP.tar.gz \$S3_BUCKET_PATH/mongodb_backup_\$TIMESTAMP.tar.gz --region \$AWS_CLI_REGION
    
    if [ \$? -eq 0 ]; then
        echo "S3 upload successful."
    else
        echo "S3 upload FAILED."
    fi
    rm -rf \$BACKUP_DIR/*
else
    echo "mongodump FAILED or produced no data. Backup directory \$BACKUP_DIR/\$TIMESTAMP not found or is empty."
fi
echo "MongoDB backup script finished at \$(date)."
EOT

    chmod +x /usr/local/bin/mongodb_backup.sh
    (crontab -l 2>/dev/null; echo "*/15 * * * * /usr/local/bin/mongodb_backup.sh >> /var/log/mongodb_backup.log 2>&1") | crontab -
    echo "SUCCESS: Cron job for MongoDB backup configured."
fi
echo "S3 backup setup process completed."
echo "User data script finished successfully."