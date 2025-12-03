#!/bin/sh

set -e

RSYNC_USER="backupuser"

# Check for required environment variables
if [ -z "$RSYNC_PASSWORD" ]; then
    echo "Error: RSYNC_PASSWORD environment variable is not set."
    exit 1
fi

# Check if the user exists and delete it
# This step prevents the 'user already exists' error on restart.
if id -u "${RSYNC_USER}" >/dev/null 2>&1; then
    echo "Deleting existing user ${RSYNC_USER}..."
    deluser "${RSYNC_USER}"
fi

# Check if the group exists and modify/create it
if getent group "${RSYNC_USER}" >/dev/null 2>&1; then
        echo "Delete group ${RSYNC_USER}..."
        groupdel "${RSYNC_USER}"
fi

# Create a rsync user
# If HOST_UID and HOST_GID are set, use them.
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
  echo "HOST_UID and HOST_GID are set. Creating ${RSYNC_USER} with UID=$HOST_UID and GID=$HOST_GID"
  addgroup -g "$HOST_GID" ${RSYNC_USER}
  adduser -D -h /data/backups -u "$HOST_UID" -G ${RSYNC_USER} ${RSYNC_USER}
  # Otherwise, create the user with default IDs.
else
  echo "HOST_UID and HOST_GID are not set. Creating ${RSYNC_USER} with default UID/GID."
  adduser -D -h /data/backups ${RSYNC_USER}
fi

# Set ownership of the backups directory.
echo "Setting ownership of /data/backups"
chown ${RSYNC_USER}:${RSYNC_USER} /data/backups

# Create WireGuard configuration directory
mkdir -p /etc/wireguard

# Generate server keys and configuration if they don't exist
if [ ! -f "/etc/wireguard/server_private_key" ]; then
    echo "First run: Generating WireGuard server keys and configuration..."
    wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
    chmod 600 /etc/wireguard/server_private_key /etc/wireguard/server_public_key
    echo "===================================================="
    echo "Dumping public server key to the logs:"
    cat /etc/wireguard/server_public_key
    echo "===================================================="

    # Create WireGuard configuration
    cat > /etc/wireguard/wg0.conf <<EOL
[Interface]
Address = 10.6.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server_private_key)

[Peer]
# PublicKey = INSERT_CLIENT_PUBLIC_KEY_HERE
AllowedIPs = 10.6.0.2/32
EOL
    echo "Please edit /etc/wireguard/wg0.conf to add your client's public key"
fi

# Extract IP from wireguard to config and set it as the authorized sender in rsync
REMOTE_IP=$(grep -E '^AllowedIPs' /etc/wireguard/wg0.conf  |\
                grep -E '/32$' | \
                head -n 1 | \
                sed -re 's/^(AllowedIPs += +(([0-9]{1,3}\.){3}[0-9]{1,3})\/32)?.*/\2/')
if [ "$REMOTE_IP" == "" ]; then
    echo "Error in AllowedIPs format in wg0.conf"
    exit 1
fi
echo "Hosts allowed to connect has IP: ${REMOTE_IP}"
sed -i -e 's/^\([ \t]*hosts allow = \).*$/\1'$REMOTE_IP'/' /etc/rsyncd.conf

# Create rsync secrets file
echo "Creating rsync secrets file..."
echo "${RSYNC_USER}:$RSYNC_PASSWORD" > /etc/rsyncd.secrets
chmod 600 /etc/rsyncd.secrets

# Checking backup dir
echo "Checking write access to backup directory"
ls -alFd /data/backups
cd /data/backups && touch .

# Start WireGuard
echo "Starting WireGuard..."

# Check if the client public key has been configured
if grep -q "# PublicKey = INSERT_CLIENT_PUBLIC_KEY_HERE" /etc/wireguard/wg0.conf; then
    echo "Error: WireGuard client public key is not configured in /etc/wireguard/wg0.conf"
    exit 1
fi

wg-quick up wg0

# Start rsync daemon
echo "Starting rsync daemon..."
rsync --daemon --no-detach --config=/etc/rsyncd.conf

# Keep the container running
echo "rsyncd-wg container is running."
tail -f /dev/null
