# Server Installation and Configuration Guide

This guide details the steps to set up a server environment including static IP, SSH, ZeroTier, Unbound DNS, Docker, Portainer, Samba, Nextcloud AIO via Cloudflare Tunnel, and Cockpit.

**Note:** Most commands require `sudo` privileges. Run them accordingly or execute the entire process as root.

---
## 1. System Update
First, ensure your system's package list is up-to-date and upgrade all installed packages to their latest versions:

```bash
sudo apt update && sudo apt upgrade -y
```

## 2. Config static IP address
```bash
ip a
```
(Check current network interfaces)

Edit the Netplan configuration file. Replace the example values with your desired static IP, gateway, and initial DNS servers (these DNS servers will be replaced by Unbound later):
```bash
sudo nano /etc/netplan/50-cloud-init.yaml 
```

```YAML
network:
  version: 2
  ethernets:
    enp0s3: # <-- Replace with your interface name
      dhcp4: no
      addresses: [192.168.1.100/24] # <-- Set your static IP and subnet mask
      routes:
        - to: default
          via: 192.168.1.1 # <-- Set your gateway IP
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8] # <-- Initial DNS (will change later)
```

Apply the new network configuration:
```bash
sudo netplan apply
```

## 3. Check ssh status
```bash
sudo systemctl status ssh
```
if the service is installed but not running:
```bash
sudo systemctl enable ssh # Enable SSH to start on boot
```
## 4. ZeroTier installation and configuration
```bash
curl -s https://install.zerotier.com | sudo bash
sudo zerotier-cli join <network_id> # Replace <network_id> with your ZeroTier network ID
```
the rest of the configuration is done via the ZeroTier web interface

## 5. Unbound DNS installation and configuration
```bash
sudo apt install unbound -y
sudo nano /etc/unbound/unbound.conf.d/local.conf #creates new config file
```
(config file is included in documentation/unbound-dns-local.conf)

Check for configuration errors:
```bash
sudo unbound-checkconf
```
result should be: ```"no errors in /etc/unbound/unbound.conf.d/local.conf"```

Restart Unbound to apply changes:
```bash
sudo systemctl restart unbound
```

Update netplan config yaml to use unbound as DNS resolver:
```bash
sudo nano /etc/netplan/50-cloud-init.yaml # Edit netplan config to set DNS to 127.0.0.1
```
Change the nameservers: ```addresses:``` line to ```[127.0.0.1]```.

Apply netplan changes:
```bash
sudo netplan apply
```
Test DNS resolution:
```bash
dig google.com # 
```
See output in ```/proofs/screenshots/03-unbound-dig-google-com.png```

## 6. Install Portainer CE for Docker container management
```bash
sudo docker volume create portainer_data
sudo docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
sudo docker ps # Verify Portainer is running
```
Access Portainer web interface at ```http://<server_ip>:9000```

## 7. Install samba for file sharing
```bash
sudo apt install samba -y
sudo mkdir -p /srv/sambashare # Create shared directory
sudo nano /etc/samba/smb.conf # Edit Samba configuration to add shared folder
```

Add your share definition at the end of the file, for example:
```Ini,TOML
[sambashare]
    comment = Samba Share for Files
    path = /srv/sambashare
    read only = no
    browsable = yes
    valid users = @staff # Or specific users like a-admin
    # Consider adding create mask, directory mask options if needed
```
change ownership and permissions:
```bash
sudo chown -R a-admin:staff /srv/sambashare
sudo chmod -R 750 /srv/sambashare
```
(```staff``` group already exists and will be used to give access to other users.)

Set directory permissions:
```bash
sudo chmod -R 750 /srv/sambashare
```

Create samba user & password:
```bash
sudo smbpasswd -a a-admin # Set Samba password for user a-admin
```

Restart and enable Samba services:
```bash
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd
```

---

# 8. Start installing nextcloud
For this example, we will use Cloudflare's free tier for DNS management and SSL and Zero Trust https://www.cloudflare.com/zero-trust/ .

Prerequisites:

 ➡️A Cloudflare account with Zero Trust configured.
 ➡️A domain managed through Cloudflare.
 ➡️The cloudflared-linux-amd64.deb package downloaded from your Cloudflare Zero Trust dashboard (assumed to be in /srv/sambashare/ for this guide).

# 8.1 Create a Tunnel in Cloudflare Zero Trust to expose Nextcloud securely
Follow the instructions at https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/installers/tunnel-guide/ .

Install cloudflared deamon from the package downloaded from Cloudflare:
```bash
sudo apt install /srv/sambashare/cloudflared-linux-amd64.deb -y
```

Configure tunnel on the cloudflared web ```/proofs/screenshots/05-zerotrust-tunnel-1.png```.

```bash
sudo cloudflared service install [YOUR-TUNNEL-UUID] # replace with your tunnel UUID is given on the web interface
```

In Cloudflare Zero Trust, create a DNS record for your Nextcloud instance (e.g., nextcloud.yourdomain.com) that points to the tunnel. The type should be ```HTTP``` and point to the ```localhost:11000```

# 8.2 Mount external storage for nextcloud data
```bash
sudo mkdir -p /mnt/ncdata/nextcloud # the repository of nextcloud reccomends this path for the data when using external storage
sudo mount /dev/sdb1 /mnt/ncdata/nextcloud # mount the external storage (replace /dev/sdb1 with your device)
```
To mount automatically on boot, edit ```/etc/fstab```:
```bash
blkid /dev/sdb1 # get the UUID of the disk
sudo nano /etc/fstab
```

Add the line:
```UUID=[FILL WITH THE DISCK UUID]  /mnt/ncdata/nextcloud  ext4  defaults  0  2```

Test fstab configuration:
```bash
sudo mount -a
```

# 8.3 install NextCloud using docker
Use compose file in ```documentation/compose.yml```.
As we are using cloudflared tunnel, we don't need to expose ports. Comment the following lines in the compose file:
```YAML
  #- 80:80 # Can be removed when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else). See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
  #- 8443:8443 # Can be removed when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else). See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
```

Also, uncomment the following lines to use the tunnel:
```YAML
      APACHE_PORT: 11000 # Is needed when running behind a web server or reverse proxy ...
      APACHE_IP_BINDING: 127.0.0.1 # Should be set when running behind a web server or reverse proxy ...
      SKIP_DOMAIN_VALIDATION: true # This should only be set to true if things are correctly configured. See https://github.com/nextcloud/all-in-one?tab=readme-ov-file#how-to-skip-the-domain-validation
```

To use an external volume to store users data change this 
```YAML
NEXTCLOUD_DATADIR: /mnt/ncdata/nextcloud # Allows to set the host directory for Nextcloud's datadir.
```
(before deployment make sure that the volume is mounted and the directory exists

We use portainer to compose the nextcloud-AIO stack
copy and paste the compose.yml file text on the portainer web interface and deploy the stack
after the stack is deployed, access nextcloud web interface at https://[SERVER-IP]:8080
follow the instructions to complete the setup
for more information, refer to the images at proofs/screenshots

# 9 Last we install cockpit for system management see the different distributions instructions at https://cockpit-project.org/running.html
```Bash
. /etc/os-release
sudo apt install -t ${VERSION_CODENAME}-backports cockpit
# If the above fails, try a standard install:
# sudo apt install cockpit -y
```

Enable cockpit to start on boot
```bash
sudo systemctl enable --now cockpit.socket
```

access cockpit web interface at https://<server_ip>:9090
cockpit gives a nice overview of system resources and logs in the web browser (log with your SO credentials).

---
Installation complete! Review all configurations and ensure services are running as expected.
