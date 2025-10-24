#!/bin/bash

# ==============================================================================
# Installation Script based on commands-instalation.sh
# ==============================================================================
# This script attempts to automate the setup process described in the provided
# repository. Some steps require manual interaction (editing files, web UI config).
# Please read the instructions carefully when prompted.
#
# IMPORTANT: Run this script with sudo or as root, as many commands require it.
#          Review the script before running to understand what it does.
#          Backup your system before making major changes.
# ==============================================================================

# --- Script Configuration ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Prevent errors in a pipeline from being masked.
set -o pipefail

# --- Helper Functions ---
print_info() {
    echo -e "\n\033[1;34m[INFO]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

prompt_continue() {
    read -p "Press Enter to continue..."
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        print_error "This script must be run as root or with sudo."
        exit 1
    fi
}

# --- Main Functions ---

update_system() {
    print_info "Updating package lists and upgrading existing packages..."
    apt update && apt upgrade -y
    print_success "System updated and upgraded."
}

configure_static_ip() {
    print_info "Configuring static IP address..."
    echo "Current network interfaces:"
    ip a
    echo "You will need to manually edit the netplan configuration file."
    echo "Example configuration for a static IP (adjust interface name, address, gateway, dns):"
    echo "
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
        addresses: [1.1.1.1, 8.8.8.8] # <-- Set your DNS servers (will be changed later for Unbound)
"
    read -p "Press Enter to open nano to edit /etc/netplan/50-cloud-init.yaml..."
    nano /etc/netplan/50-cloud-init.yaml
    print_info "Applying netplan configuration..."
    netplan apply
    print_success "Netplan configuration applied. Verify your IP address with 'ip a'."
    prompt_continue
}

setup_ssh() {
    print_info "Checking and enabling SSH service..."
    if systemctl status ssh > /dev/null 2>&1; then
        print_info "SSH service is installed."
        if ! systemctl is-enabled ssh > /dev/null 2>&1; then
            systemctl enable ssh
            print_success "SSH service enabled to start on boot."
        else
            print_info "SSH service is already enabled."
        fi
        if ! systemctl is-active ssh > /dev/null 2>&1; then
            systemctl start ssh
            print_success "SSH service started."
        else
            print_info "SSH service is already active."
        fi
    else
        print_warning "SSH server not found. Installing..."
        apt install -y openssh-server
        systemctl enable ssh
        systemctl start ssh
        print_success "SSH server installed, enabled, and started."
    fi
}

install_zerotier() {
    print_info "Installing ZeroTier..."
    if command -v zerotier-cli > /dev/null 2>&1; then
       print_info "ZeroTier already installed."
    else
       curl -s https://install.zerotier.com | bash
       print_success "ZeroTier installed."
    fi

    read -p "Please enter your ZeroTier Network ID to join: " ZT_NETWORK_ID
    if [[ -z "$ZT_NETWORK_ID" ]]; then
        print_error "Network ID cannot be empty."
        exit 1
    fi
    print_info "Joining ZeroTier network: $ZT_NETWORK_ID"
    zerotier-cli join "$ZT_NETWORK_ID"
    print_success "Successfully sent join request for network $ZT_NETWORK_ID."
    print_info "You MUST authorize this machine in the ZeroTier Central web interface (my.zerotier.com)."
    prompt_continue
}

install_unbound() {
    print_info "Installing Unbound DNS resolver..."
    apt install unbound -y

    print_info "Creating Unbound configuration file (/etc/unbound/unbound.conf.d/local.conf)..."
    # Configuration based on the user's notes - adjust as needed
    cat << EOF > /etc/unbound/unbound.conf.d/local.conf
server:
    # Verbosity level (0-5)
    verbosity: 1

    # Listen on localhost for IPv4 and IPv6
    interface: 127.0.0.1
    interface: ::1

    # Port to answer queries from
    port: 53

    # Enable IPv4 and IPv6 support
    do-ip4: yes
    do-ip6: yes

    # Accept DNS queries from localhost and local network (adjust as needed)
    access-control: 127.0.0.0/8 allow
    access-control: ::1/128 allow
    # Example for a local network: access-control: 192.168.1.0/24 allow

    # Hide identity and version
    hide-identity: yes
    hide-version: yes

    # Limit DNS query disclosure (use qname minimization)
    qname-minimisation: yes

    # Use Aggressive Use of DNSSEC-Validated Cache
    aggressive-nsec: yes

    # Root hints file (usually provided by package)
    root-hints: "/usr/share/dns/root.hints"

    # Specify forwarding servers (e.g., Cloudflare, Google)
    # Comment out if you want Unbound to resolve recursively from root servers
    forward-zone:
      name: "."
      forward-addr: 1.1.1.1@853#cloudflare-dns.com
      forward-addr: 1.0.0.1@853#cloudflare-dns.com
      forward-addr: 8.8.8.8@853#dns.google
      forward-addr: 8.8.4.4@853#dns.google
      # Use DNS over TLS
      forward-tls-upstream: yes
EOF
    print_success "Unbound local.conf created."

    print_info "Checking Unbound configuration..."
    if unbound-checkconf; then
        print_success "Unbound configuration check passed."
    else
        print_error "Unbound configuration check failed. Please review /etc/unbound/unbound.conf.d/local.conf"
        exit 1
    fi

    print_info "Restarting Unbound service..."
    systemctl restart unbound
    systemctl enable unbound
    print_success "Unbound restarted and enabled."

    print_info "Updating system DNS resolver to use Unbound (127.0.0.1)..."
    echo "You will need to manually edit the netplan configuration file again."
    echo "Change the 'nameservers: addresses:' line to only contain '127.0.0.1'."
    echo "Example:"
    echo "
network:
  version: 2
  ethernets:
    enp0s3: # <-- Your interface name
      # ... other settings ...
      nameservers:
        addresses: [127.0.0.1] # <-- Set DNS to localhost
"
    read -p "Press Enter to open nano to edit /etc/netplan/50-cloud-init.yaml..."
    nano /etc/netplan/50-cloud-init.yaml
    print_info "Applying netplan configuration..."
    netplan apply
    print_success "Netplan configuration applied."
    print_info "Testing DNS resolution with 'dig google.com @127.0.0.1'. Check the output carefully."
    dig google.com @127.0.0.1
    prompt_continue
}

install_docker() {
    print_info "Checking for Docker installation..."
    if command -v docker > /dev/null 2>&1; then
        print_info "Docker is already installed."
    else
        print_info "Installing Docker..."
        # Add Docker's official GPG key:
        apt update
        apt install -y ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        # Add the repository to Apt sources:
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update

        # Install Docker packages
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        print_success "Docker installed successfully."
    fi
    # Add current user to docker group to run docker without sudo (optional, requires logout/login)
    # read -p "Enter your regular username to add to the docker group (optional): " DOCKER_USER
    # if [[ -n "$DOCKER_USER" ]]; then
    #    usermod -aG docker "$DOCKER_USER"
    #    print_info "User $DOCKER_USER added to docker group. You need to log out and log back in for this to take effect."
    # fi
}


install_portainer() {
    print_info "Installing Portainer CE..."
    if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        print_info "Portainer container already exists."
    else
        print_info "Creating Portainer data volume..."
        docker volume create portainer_data

        print_info "Running Portainer container..."
        docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart always \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v portainer_data:/data \
          portainer/portainer-ce:latest

        print_success "Portainer container is running."
        echo "Access Portainer web interface at http://<your_server_ip>:9000 to complete setup."
        prompt_continue
    fi
}

install_samba() {
    print_info "Installing Samba..."
    apt install samba -y

    SAMBA_SHARE_PATH="/srv/sambashare"
    print_info "Creating Samba share directory: $SAMBA_SHARE_PATH"
    mkdir -p "$SAMBA_SHARE_PATH"

    print_info "Setting ownership and permissions for Samba share..."
    # Ensure staff group exists, create if not (though it usually does)
    if ! getent group staff > /dev/null; then
        groupadd staff
    fi
    # Ensure user exists (assuming a-admin is the desired user)
    if ! id "a-admin" > /dev/null 2>&1; then
        print_warning "User 'a-admin' does not exist. Please create it first (e.g., sudo adduser a-admin)."
        # Or create a basic user: useradd -m -g staff a-admin
        # For now, we'll proceed assuming it exists or user handles it.
    fi
    chown -R a-admin:staff "$SAMBA_SHARE_PATH"
    chmod -R 750 "$SAMBA_SHARE_PATH"
    print_success "Ownership and permissions set."

    print_info "Adding Samba share configuration to /etc/samba/smb.conf..."
    echo "You need to manually add the share definition to the end of smb.conf."
    echo "Example share definition:"
    echo "
[sambashare]
    comment = Samba Share for Files
    path = /srv/sambashare
    read only = no
    browsable = yes
    valid users = @staff # Or specific users like a-admin
    # Add other options as needed, e.g., create mask, directory mask
"
    read -p "Press Enter to open nano to edit /etc/samba/smb.conf..."
    nano /etc/samba/smb.conf

    print_info "Restarting Samba service..."
    systemctl restart smbd nmbd
    systemctl enable smbd nmbd
    print_success "Samba restarted and enabled."

    print_info "Setting Samba password for user 'a-admin'..."
    smbpasswd -a a-admin
    print_success "Samba password set. You can now connect to the share (e.g., \\\\<server_ip>\\sambashare)."
    prompt_continue
}

setup_cloudflared() {
    print_info "Setting up Cloudflared Tunnel..."
    CLOUDFLARED_DEB_PATH="/srv/sambashare/cloudflared-linux-amd64.deb" # Assuming download location

    if [[ ! -f "$CLOUDFLARED_DEB_PATH" ]]; then
       print_error "Cloudflared .deb package not found at $CLOUDFLARED_DEB_PATH."
       echo "Please download it from Cloudflare Zero Trust dashboard and place it there,"
       echo "or update the CLOUDFLARED_DEB_PATH variable in this script."
       exit 1
    fi

    print_info "Installing Cloudflared package..."
    apt install "$CLOUDFLARED_DEB_PATH" -y
    print_success "Cloudflared installed."

    print_info "Please configure your Tunnel in the Cloudflare Zero Trust dashboard now."
    echo "Follow instructions at: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/installers/tunnel-guide/"
    echo "Once created, you will get a Tunnel UUID."
    read -p "Please enter your Cloudflare Tunnel UUID: " CF_TUNNEL_UUID
    if [[ -z "$CF_TUNNEL_UUID" ]]; then
        print_error "Tunnel UUID cannot be empty."
        exit 1
    fi

    print_info "Installing Cloudflared service for tunnel $CF_TUNNEL_UUID..."
    cloudflared service install "$CF_TUNNEL_UUID"
    print_success "Cloudflared service installed. It should start automatically."
    echo "Verify service status with: systemctl status cloudflared"
    prompt_continue
}

setup_nextcloud_storage() {
    print_info "Setting up external storage mount for Nextcloud..."
    NCDATA_PATH="/mnt/ncdata/nextcloud" # Path consistent with original notes
    mkdir -p "$NCDATA_PATH"

    echo "Available block devices:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
    read -p "Enter the device name for Nextcloud data (e.g., /dev/sdb1): " NC_DEVICE
    if [[ -z "$NC_DEVICE" ]] || [[ ! -b "$NC_DEVICE" ]]; then
        print_error "Invalid or empty device name provided: $NC_DEVICE"
        exit 1
    fi

    print_info "Mounting $NC_DEVICE to $NCDATA_PATH..."
    # Check if already mounted to avoid errors
    if findmnt -rno TARGET "$NC_DEVICE" | grep -q "^$NCDATA_PATH$"; then
        print_info "$NC_DEVICE is already mounted to $NCDATA_PATH."
    else
       mount "$NC_DEVICE" "$NCDATA_PATH"
       print_success "$NC_DEVICE mounted temporarily."
    fi


    print_info "Configuring automatic mount in /etc/fstab..."
    DEVICE_UUID=$(blkid -s UUID -o value "$NC_DEVICE")
    if [[ -z "$DEVICE_UUID" ]]; then
        print_error "Could not retrieve UUID for $NC_DEVICE. Cannot configure fstab."
        exit 1
    fi
    FSTAB_LINE="UUID=$DEVICE_UUID  $NCDATA_PATH  ext4  defaults  0  2"

    # Avoid adding duplicate lines
    if grep -qF "$FSTAB_LINE" /etc/fstab; then
        print_info "fstab entry already exists."
    else
        echo "The following line will be added to /etc/fstab:"
        echo "$FSTAB_LINE"
        read -p "Do you want to add this line automatically? (y/N): " CONFIRM_FSTAB
        if [[ "${CONFIRM_FSTAB,,}" == "y" ]]; then
            echo "$FSTAB_LINE" >> /etc/fstab
            print_success "fstab updated."
            print_info "Testing fstab configuration with 'mount -a'..."
            if mount -a; then
               print_success "fstab test successful."
            else
               print_error "fstab test failed. Check /etc/fstab for errors before rebooting!"
               exit 1
            fi
        else
            print_warning "fstab not modified. You need to add the mount point manually to ensure it persists after reboot."
            echo "Add this line to /etc/fstab:"
            echo "$FSTAB_LINE"
        fi
    fi
    prompt_continue
}

setup_nextcloud_docker() {
    print_info "Setting up Nextcloud AIO via Docker Compose..."
    echo "This script cannot automatically deploy the stack using Portainer's web UI."
    echo "Please perform the following steps manually:"
    echo "1. Ensure you have the 'compose.yml' file (e.g., in ./documentation/compose.yml)."
    echo "2. Edit the 'compose.yml' file:"
    echo "   - Comment out the 'ports:' section (80:80 and 8443:8443)."
    echo "   - Uncomment and configure the Cloudflare environment variables:"
    echo "     - CLOUDFLARED_TUNNEL=YOUR-TUNNEL-UUID (Use the UUID from the previous step)"
    echo "     - CLOUDFLARED_CRED_FILE=/etc/cloudflared/YOUR-TUNNEL-FILE.json (Ensure this path is correct)"
    echo "   - Uncomment and set APACHE_PORT (e.g., APACHE_PORT: 11000)."
    echo "   - Uncomment and set APACHE_IP_BINDING: 127.0.0.1."
    echo "   - Uncomment SKIP_DOMAIN_VALIDATION: true (use cautiously)."
    echo "   - Make sure the volume for Nextcloud data points to '$NCDATA_PATH' (or adjust as needed)."
    echo "3. Go to your Portainer web interface (http://<server_ip>:9000)."
    echo "4. Navigate to 'Stacks' -> 'Add stack'."
    echo "5. Give the stack a name (e.g., 'nextcloud-aio')."
    echo "6. Select 'Web editor' and paste the entire modified content of your 'compose.yml' file."
    echo "7. Click 'Deploy the stack'."
    echo "8. Configure Cloudflare Zero Trust:"
    echo "   - Create a Public Hostname DNS record for your Nextcloud (e.g., nextcloud.yourdomain.com)."
    echo "   - Point it to your Tunnel."
    echo "   - Set the Service Type to HTTP and the URL to localhost:11000 (matching APACHE_PORT)."
    echo "9. Wait for deployment, then access the Nextcloud AIO setup interface via your configured domain (e.g., https://nextcloud.yourdomain.com)."
    echo "   (Initial AIO setup might also be accessible via https://<server_ip>:8080 or 8443 if ports were left open temporarily)."
    echo "10. Follow the Nextcloud AIO setup instructions in the web interface."

    prompt_continue
}

install_cockpit() {
    print_info "Installing Cockpit web interface..."
    # Source os-release to get VERSION_CODENAME
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        print_error "Cannot find /etc/os-release to determine Ubuntu version codename."
        exit 1
    fi

    # Check if backports repository is needed and available - this might vary
    # For simplicity, we'll try installing directly first, then suggest backports if needed.
    if apt install -y cockpit; then
        print_success "Cockpit installed."
    else
        print_warning "Direct installation failed, trying with backports..."
        if [[ -n "${VERSION_CODENAME-}" ]]; then
           if apt install -t "${VERSION_CODENAME}-backports" cockpit -y; then
              print_success "Cockpit installed from backports."
           else
              print_error "Failed to install Cockpit even from backports. Please check APT configuration."
              exit 1
           fi
        else
           print_error "VERSION_CODENAME not found. Cannot install Cockpit from backports."
           exit 1
        fi
    fi

    print_info "Enabling and starting Cockpit socket..."
    systemctl enable --now cockpit.socket
    print_success "Cockpit socket enabled and started."
    echo "Access Cockpit web interface at https://<your_server_ip>:9090"
    prompt_continue
}

# --- Script Execution ---

check_root

update_system
# configure_static_ip # Uncomment if you want interactive static IP setup
setup_ssh
install_zerotier
install_unbound
install_docker
install_portainer
install_samba
# setup_cloudflared # Uncomment after downloading the .deb and configuring Cloudflare Tunnel
# setup_nextcloud_storage # Uncomment when you are ready to mount the external disk
# setup_nextcloud_docker # Provides manual instructions for Portainer deployment
install_cockpit

print_success "Script finished. Please review any manual steps or prompts."
print_info "Remember to verify all services and configurations."

exit 0