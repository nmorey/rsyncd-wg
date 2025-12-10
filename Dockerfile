# Use a lightweight base image
FROM alpine:3.20

# Install necessary packages
RUN apk add --no-cache rsync wireguard-tools

# Create the user/group with a fixed ID initially (can be changed at runtime)
RUN addgroup -g 1000 backupuser && \
    adduser -D -h /data/backups -u 1000 -G backupuser backupuser

# Prepare directories
RUN mkdir -p /data/backups /etc/wireguard && \
    chown backupuser:backupuser /data/backups

# Copy the configuration files
COPY rsyncd.conf /etc/rsyncd.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose the WireGuard port
EXPOSE 51820/udp

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
