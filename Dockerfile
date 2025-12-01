# Use a lightweight base image
FROM alpine:3.20

# Install necessary packages
RUN apk add --no-cache rsync wireguard-tools

# Create a directory for the data that will be backed up
RUN mkdir -p /data/backups

# Copy the configuration files
COPY rsyncd.conf /etc/rsyncd.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose the WireGuard port
EXPOSE 51820/udp

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
