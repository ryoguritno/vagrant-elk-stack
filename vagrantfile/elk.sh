#!/bin/bash

echo "**** Begin installing Docker"

sudo apt-get update && sudo apt-get install -y git curl

# Install Docker
if ! command -v docker &>/dev/null; then
  echo "Docker not found, installing..."
  curl -fsSL https://get.docker.com/ | sh
  echo "Docker installed successfully."
fi

# Install Docker Compose
if ! command -v docker-compose &>/dev/null; then
  echo "Docker Compose not found, installing..."
  sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '\"tag_name\": \"\K(.*)(?=\")')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose
  sudo usermod -aG docker vagrant
  echo "Docker Compose installed successfully."
fi

echo "**** Configuring system for OpenSearch"
sudo sysctl -w vm.max_map_count=512000

echo "**** Changing to OpenSearch directory"
cd /home/vagrant/opensearch-docker-compose

# Generate Certificates if they don't exist
if [ ! -f "certs/ca/ca.pem" ]; then
  echo "**** Generating certificates"
  bash generate-certs.sh &>/home/vagrant/opensearch-docker-compose/generate-certs-debug.log
else
  echo "**** Certificates already exist"
fi

echo "**** Starting OpenSearch cluster with Docker Compose"
docker-compose up -d

echo "**** Waiting 30 seconds for cluster to be ready..."
sleep 30

echo "**** Initializing OpenSearch security"
docker-compose exec os01 bash -c "chmod +x plugins/opensearch-security/tools/securityadmin.sh && bash plugins/opensearch-security/tools/securityadmin.sh -cd config/opensearch-security -icl -nhnv -cacert config/certificates/ca/ca.pem -cert config/certificates/ca/admin.pem -key config/certificates/ca/admin.key -h os01"

echo "**** End of OpenSearch Setup Script"
