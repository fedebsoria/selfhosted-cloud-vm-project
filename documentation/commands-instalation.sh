#!/bin/bash
# This script provides installation instructions for various commands.
#1 Update package lists and upgrade existing packages
sudo apt update && sudo apt upgrade -y

#2 config static IP address
ip a # Check current network interfaces (enp0se3)
sudo nano /etc/netplan/50-cloud-init.yaml 
sudo netplan apply

#3 check ssh status
sudo systemctl status ssh
# the service is installed but not running
sudo systemctl enable ssh # Enable SSH to start on boot

#4 mount external drive for nextcloud storage
lsblk # Identify the external drive (sdb)
#disk is unformatted
sudo fdisk /dev/sdb # options used: n (new partition), p (primary), 1 (partition number), default (first sector), default (last sector), w (write changes)
sudo mkfs.ext4 /dev/sdb1 # Format the new partition with ext4 filesystem
sudo mkdir ~/nextcloud_data # Create mount point
sudo mount /dev/sdb1 ~/nextcloud_data # Mount the partition

#5 zero tier installation and configuration
curl -s https://install.zerotier.com | sudo bash
sudo zerotier-cli join <network_id> # Replace <network_id> with your ZeroTier network ID
#the rest of the configuration is done via the ZeroTier web interface

#6 unbound DNS installation and configuration
sudo apt install unbound -y
sudo nano /etc/unbound/unbound.conf.d/local.conf #creates new config file
# config file is included in documentation/unbound-dns-local.conf
sudo unbound-checkconf # Check for configuration errors
# result should be: "no errors in /etc/unbound/unbound.conf.d/local.conf"
sudo systemctl restart unbound # Restart Unbound to apply changes
# update netplan config yaml to use unbound as DNS resolver
sudo nano /etc/netplan/50-cloud-init.yaml # Edit netplan config to set DNS to 127.0.0.1
sudo netplan apply # Apply netplan changes
dig google.com # Test DNS resolution. See output in /proofs/screenshots/03-unbound-dig-google-com.png

#5 install Portainer CE for Docker container management
sudo docker volume create portainer_data
sudo docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
sudo docker ps # Verify Portainer is running
# Access Portainer web interface at http://<server_ip>:9000

#6 install samba for file sharing
sudo apt install samba -y
sudo mkdir -p /srv/sambashare # Create shared directory
sudo nano /etc/samba/smb.conf # Edit Samba configuration to add shared folder
# change ownership and permissions
sudo chown -R a-admin:staff /srv/sambashare #staff group already exists and will be used to give access to other users
sudo chmod -R 750 /srv/sambashare # Set directory permissions
# create samba user
sudo smbpasswd -a a-admin # Set Samba password for user a-admin