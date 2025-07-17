#!/bin/sh

set -e

# Check for required environment variables
if [ -z "$WG_CLIENT_PUBLIC_KEY" ]; then
    echo "Error: WG_CLIENT_PUBLIC_KEY environment variable is not set."
    exit 1
fi

if [ -z "$RSYNC_PASSWORD" ]; then
    echo "Error: RSYNC_PASSWORD environment variable is not set."
    exit 1
fi

# Create WireGuard configuration directory
mkdir -p /etc/wireguard

# Generate server keys if they don't exist
if [ ! -f "/etc/wireguard/server_private_key" ]; then
    echo "Generating WireGuard server keys..."
    wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
    echo "===================================================="
    echo "Dumping public server key to the logs:"
    cat /etc/wireguard/server_public_key
    echo "===================================================="
fi

# Create WireGuard configuration
echo "Creating WireGuard configuration..."
cat > /etc/wireguard/wg0.conf <<EOL
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server_private_key)

[Peer]
PublicKey = $WG_CLIENT_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32
EOL

# Create rsync secrets file
echo "Creating rsync secrets file..."
echo "backupuser:$RSYNC_PASSWORD" > /etc/rsyncd.secrets
chmod 600 /etc/rsyncd.secrets

# Start WireGuard
echo "Starting WireGuard..."
wg-quick up wg0

# Start rsync daemon
echo "Starting rsync daemon..."
rsync --daemon --no-detach --config=/etc/rsyncd.conf

# Keep the container running
echo "Secure backup container is running."
tail -f /dev/null
