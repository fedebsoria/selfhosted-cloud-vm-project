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

#4 zero tier installation and configuration
curl -s https://install.zerotier.com | sudo bash
sudo zerotier-cli join <network_id> # Replace <network_id> with your ZeroTier network ID
#the rest of the configuration is done via the ZeroTier web interface

#5 unbound DNS installation and configuration
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

#6 install Portainer CE for Docker container management
sudo docker volume create portainer_data
sudo docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
sudo docker ps # Verify Portainer is running
# Access Portainer web interface at http://<server_ip>:9000

#7 install samba for file sharing
sudo apt install samba -y
sudo mkdir -p /srv/sambashare # Create shared directory
sudo nano /etc/samba/smb.conf # Edit Samba configuration to add shared folder
# change ownership and permissions
sudo chown -R a-admin:staff /srv/sambashare #staff group already exists and will be used to give access to other users
sudo chmod -R 750 /srv/sambashare # Set directory permissions
# create samba user
sudo smbpasswd -a a-admin # Set Samba password for user a-admin

#8 start installing nextcloud
# Nextcloud offers a free domain with SSL certificate https://desec.io/
# For this example, we will use Cloudflare's free tier for DNS management and SSL and Zero Trust https://www.cloudflare.com/zero-trust/
#8.1 Create a Tunnel in Cloudflare Zero Trust to expose Nextcloud securely
# Follow the instructions at https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/installers/tunnel-guide/
sudo apt install /srv/sambashare/cloudflared-linux-amd64.deb -y # install cloudflared deamon from the package downloaded from Cloudflare
# configure tunnel on the cloudflared web /proofs/screenshots/05-zerotrust-tunnel-1.png
sudo cloudflared service install [YOUR-TUNNEL-UUID] # replace with your tunnel UUID is given on the web interface

#8.2 mount external storage for nextcloud data
sudo mkdir -p /mnt/ncdata/nextcloud # the repository of nextcloud reccomends this path for the data when using external storage
sudo mount /dev/sdb1 /mnt/ncdata/nextcloud # mount the external storage (replace /dev/sdb1 with your device)
# to mount automatically on boot, edit /etc/fstab
sudo nano /etc/fstab
# add the line:
# UUID=[FILL WITH THE DISCK UUID]  /mnt/ncdata/nextcloud  ext4  defaults  0  2

#8.2 install nextcloud using docker
# use compose file in documentation/compose.yml
# as we are using cloudflared tunnel, we don't need to expose ports. Comment the following lines in the compose file:
  #- 80:80 # Can be removed when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else). See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
  #- 8443:8443 # Can be removed when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else). See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
# also, uncomment the following lines to use the tunnel:
      - CLOUDFLARED_TUNNEL=YOUR-TUNNEL-UUID
      - CLOUDFLARED_CRED_FILE=/etc/cloudflared/YOUR-TUNNEL-FILE.json
#      APACHE_PORT: 11000 # Is needed when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else). See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
#      APACHE_IP_BINDING: 127.0.0.1 # Should be set when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else) that is running on the same host. See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
#      SKIP_DOMAIN_VALIDATION: true # This should only be set to true if things are correctly configured. See https://github.com/nextcloud/all-in-one?tab=readme-ov-file#how-to-skip-the-domain-validation
