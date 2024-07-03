#!/bin/bash

# Function to generate random password
generate_password() {
  local password
  password=$(openssl rand -base64 12)
  echo "$password"
}

# Step 1: Check if the input file is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <input-file>"
  exit 1
fi

input_file="$1"

# Step 2: Ensure the log and password directories exist
mkdir -p /var/log
mkdir -p /var/secure

# Step 3: Define the log and password files
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.csv"

# Step 4: Clear previous log and password files
> "$log_file"
> "$password_file"

# Step 5: Set appropriate permissions for password file
chmod 600 "$password_file"

# Step 6: Process each line in the input file
while IFS=";" read -r username groups; do
  # Trim whitespaces
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)
  
  #Checks if user already exists
  if id "$username" &>/dev/null; then
    echo "User $username already exists, skipping..." | tee -a "$log_file"
    continue
  fi

  #Creates user and personal group
  useradd -m -s /bin/bash "$username"
  echo "Created user $username" | tee -a "$log_file"

  #Generates and set password
  password=$(generate_password)
  echo "$username:$password" | chpasswd
  echo "$username,$password" >> "$password_file"
  echo "Set password for user $username" | tee -a "$log_file"

  #Assigning user to groups
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs) # Trim whitespaces
    if ! getent group "$group" &>/dev/null; then
      groupadd "$group"
      echo "Created group $group" | tee -a "$log_file"
    fi
    usermod -aG "$group" "$username"
    echo "Added user $username to group $group" | tee -a "$log_file"
  done

  #Setting permissions for the home directory
  chown "$username:$username" "/home/$username"
  chmod 700 "/home/$username"
  echo "Set permissions for /home/$username" | tee -a "$log_file"

done < "$input_file"

echo "User creation and setup complete. Check $log_file and $password_file for details."

