#!/bin/sh

set -e

# Check for required environment variables
if [ -z "$RSYNC_PASSWORD" ]; then
    echo "Error: RSYNC_PASSWORD environment variable is not set."
    exit 1
fi

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
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server_private_key)

[Peer]
# PublicKey = INSERT_CLIENT_PUBLIC_KEY_HERE
AllowedIPs = 10.0.0.2/32
EOL
    echo "Please edit /etc/wireguard/wg0.conf to add your client's public key"
fi



# Create rsync secrets file
echo "Creating rsync secrets file..."
echo "backupuser:$RSYNC_PASSWORD" > /etc/rsyncd.secrets
chmod 600 /etc/rsyncd.secrets

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
