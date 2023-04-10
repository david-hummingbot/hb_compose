#!/bin/bash

# Set default values
DEFAULT_NUM_INSTANCES=2
DEFAULT_INCLUDE_GATEWAY="n"
DEFAULT_ARM_DEVICE="n"

# Print instructions for the user
echo "This script will create a Docker Compose file for running Hummingbot instances."
echo "You will be prompted to enter the number of instances, instance names, whether to include a gateway instance, and whether you are using an ARM device."
echo "Press Enter to use the default values (shown in brackets)."

# Prompt user for input on the number of instances
read -p "Enter the number of Hummingbot instances you want [${DEFAULT_NUM_INSTANCES}]: " num_instances
num_instances=${num_instances:-$DEFAULT_NUM_INSTANCES}

# Prompt user for input on whether to include a gateway instance
read -p "Do you want to include a gateway instance? (y/n) [${DEFAULT_INCLUDE_GATEWAY}]: " include_gateway
include_gateway=${include_gateway:-$DEFAULT_INCLUDE_GATEWAY}

# Prompt user for input on whether they are using an ARM device
read -p "Are you using an ARM device like Mac M1 or M2? (y/n) [${DEFAULT_ARM_DEVICE}]: " arm_device
arm_device=${arm_device:-$DEFAULT_ARM_DEVICE}

# Use the appropriate Hummingbot Docker image depending on the device
if [ "$arm_device" == "y" ]
then
    HUMMINGBOT_IMAGE="hummingbot/hummingbot:latest-arm"
    GATEWAY_IMAGE="hummingbot/gateway:latest-arm"
else
    HUMMINGBOT_IMAGE="hummingbot/hummingbot:latest"
    GATEWAY_IMAGE="hummingbot/gateway:latest"
fi

# Create the Docker Compose file
cat << EOF > docker-compose.yml
version: '3.9'
services:
EOF

# Loop through each instance and prompt user for input
for (( i=1; i<=$num_instances; i++ ))
do
    # Prompt user for input
    read -p "Enter the name of Hummingbot instance $i: " instance_name
    
    # Check if the instance name already exists
    while [ -d "$instance_name" ]; do
        read -p "The instance name already exists. Please enter a unique name: " instance_name
    done

    # Add the service to the Docker Compose file
    cat << EOF >> docker-compose.yml
  bot$i:
    container_name: ${instance_name}
    image: $HUMMINGBOT_IMAGE
    volumes:
      - "./${instance_name}/conf:/conf"
      - "./${instance_name}/conf/connectors:/conf/connectors"
      - "./${instance_name}/conf/strategies:/conf/strategies"
      - "./${instance_name}/logs:/logs"
      - "./${instance_name}/data:/data"
      - "./${instance_name}/scripts:/scripts"
      - "./${instance_name}/certs:/certs"
    logging:
      driver: "json-file"
      options:
          max-size: "10m"
          max-file: 5
    tty: true
    stdin_open: true
    network_mode: host

EOF

    # Create the instance directory and necessary files
    mkdir $instance_name
    mkdir $instance_name/conf
    mkdir $instance_name/conf/connectors
    mkdir $instance_name/conf/strategies
    mkdir $instance_name/logs
    mkdir $instance_name/data
    mkdir $instance_name/scripts
    mkdir $instance_name/certs
	
	sudo chmod -R a+rw $instance_name

done # This line closes the 'for' loop

# Add gateway bot to the Docker Compose file if specified by user
if [ "$include_gateway" == "y" ]
then
    # Prompt user for input
    read -p "Enter the name of the gateway instance: " gateway_name
    
    # Check if the gateway name already exists
    while [ -d "$gateway_name" ]; do
        read -p "The gateway instance name already exists. Please enter a unique name: " gateway_name
    done
	
	# Prompt user for HB passphrase
	read -p "Enter the Hummingbot passphrase: " gateway_passphrase
    

    # Add the service to the Docker Compose file
    cat << EOF >> docker-compose.yml
  gateway:
    container_name: ${gateway_name}
    image: $GATEWAY_IMAGE
    ports:
      - "15888:15888"
      - "8080:8080"
    volumes:
      - "./${gateway_name}/conf:/usr/src/app/conf"
      - "./${gateway_name}/logs:/usr/src/app/logs"
      - "./${instance_name}/certs:/certs"
    environment:
      - GATEWAY_PASSPHRASE=${gateway_passphrase}

EOF

    # Create the gateway instance directory and necessary files
    mkdir $gateway_name
    mkdir $gateway_name/conf
    mkdir $gateway_name/logs
	
	sudo chmod -R a+rw $gateway_name
    
fi

# Prompt the user if they want to run the bot
read -p "Docker Compose file successfully created. Do you want to run the bot now? (y/n): " run_bot

if [ "$run_bot" == "y" ]
then
    # Start the bot using Docker Compose
    docker compose up -d

fi
