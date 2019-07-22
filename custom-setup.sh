#!/bin/sh
echo "Updating packages..."
sudo apt update
sudo apt upgrade -y

echo "Installing Docker CE..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo apt-key fingerprint 0EBFCD88

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io

echo "Installing Docker Compose..."

sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

echo "Setting up Docker TLS & Securing the Daemon..."

echo "Move TLS Certs"
sudo mkdir -p /etc/docker/ssl
# TODO: Need to get admin username from main script
sudo mv /home/absadmin/ca.pem /etc/docker/ssl/
sudo mv /home/absadmin/server-cert.pem /etc/docker/ssl/
sudo mv /home/absadmin/server-key.pem /etc/docker/ssl/

echo "Move daemon.json"
sudo mv /home/absadmin/daemon.json /etc/docker/

echo "Move override.conf"
sudo mkdir -p /etc/systemd/system/docker.service.d/
sudo mv /home/absadmin/override.conf /etc/systemd/system/docker.service.d/

echo "Reload the systemd daemon"
sudo systemctl daemon-reload

echo "Enable docker"
sudo systemctl enable docker

echo "Restart Docker"
sudo systemctl start docker

# echo "Reboot VM"
# sudo reboot

echo "Reboot VM"
sudo shutdown -r +2

# Run docker as non-root user (although docker group is near root)
#sudo groupadd docker
# echo "Run Docker as non-root"
# sudo usermod -aG docker $USER
