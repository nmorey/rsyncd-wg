#!/bin/sh
set -e

# Define standard user
RSYNC_USER="backupuser"
RSYNC_GROUP="backupuser"

# trap SIGTERM and SIGINT to shutdown wireguard cleanly
cleanup() {
    echo "Shutting down WireGuard..."
    wg-quick down wg0 || true
    exit 0
}
trap cleanup TERM INT

# --- User Management ---
# If HOST_UID/GID are passed, modify the existing user instead of deleting/recreating
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    echo "Updating $RSYNC_USER to UID $HOST_UID / GID $HOST_GID"
    # Change the group ID
    sed -i "s/^$RSYNC_GROUP:x:[0-9]*:/$RSYNC_GROUP:x:$HOST_GID:/" /etc/group
    # Change the user ID
    sed -i "s/^$RSYNC_USER:x:[0-9]*:[0-9]*:/$RSYNC_USER:x:$HOST_UID:$HOST_GID:/" /etc/passwd
fi

# Check ownership of the data directory root
CURRENT_OWNER=$(stat -c '%u:%g' /data/backups)
TARGET_OWNER="$HOST_UID:$HOST_GID"

if [ "$CURRENT_OWNER" != "$TARGET_OWNER" ]; then
    echo "Ownership mismatch ($CURRENT_OWNER vs $TARGET_OWNER). Fixing permissions..."
    chown "$HOST_UID:$HOST_GID" /data/backups
else
    echo "Permissions on /data/backups are correct. Skipping chown."
fi

# --- WireGuard Setup ---
mkdir -p /etc/wireguard
if [ ! -f "/etc/wireguard/server_private_key" ]; then
    echo "Generating new keys..."
    wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
    chmod 600 /etc/wireguard/server_*
    echo "===================================================="
    echo "Dumping public server key to the logs:"
    cat /etc/wireguard/server_public_key
    echo "===================================================="

    # Generate default config
    cat > /etc/wireguard/wg0.conf <<EOL
[Interface]
Address = 10.6.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server_private_key)
[Peer]
AllowedIPs = 10.6.0.2/32
EOL
    echo "Please edit /etc/wireguard/wg0.conf to add your client's public key"
fi

# Dynamically update AllowedIPs in rsyncd.conf based on wg0.conf
REMOTE_IP=$(grep -E '^AllowedIPs' /etc/wireguard/wg0.conf  |\
                grep -E '/32$' | \
                head -n 1 | \
                sed -re 's/^(AllowedIPs += +(([0-9]{1,3}\.){3}[0-9]{1,3})\/32)?.*/\2/')
if [ "$REMOTE_IP" == "" ]; then
    echo "Error in AllowedIPs format in wg0.conf"
    exit 1
else
    echo "Restricting rsync to WireGuard Peer IP: $REMOTE_IP"
    sed -i "s|^[ \t]*hosts allow.*|    hosts allow = $REMOTE_IP|" /etc/rsyncd.conf
fi

# Set rsync secrets
echo "Creating rsync secrets file..."
echo "$RSYNC_USER:$RSYNC_PASSWORD" > /etc/rsyncd.secrets
chmod 600 /etc/rsyncd.secrets

echo "Starting WireGuard..."
# Check if the client public key has been configured
if grep -q "# PublicKey = INSERT_CLIENT_PUBLIC_KEY_HERE" /etc/wireguard/wg0.conf; then
    echo "Error: WireGuard client public key is not configured in /etc/wireguard/wg0.conf"
    exit 1
fi

wg-quick up wg0

echo "Starting rsync daemon..."
# Remove old pid if it exists
rm -f /var/run/rsyncd.pid

# Run rsync in the foreground.
# It will drop privileges to 'backupuser' automatically because of 'uid = backupuser' in rsyncd.conf
exec rsync --daemon --no-detach --config=/etc/rsyncd.conf
