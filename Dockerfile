FROM alpine:latest

# Install necessary packages
RUN apk update && \
    apk add wireguard-tools rsync \
            wireguard-tools-wg-quick iptables

# Create directories for Wireguard
RUN mkdir -p /etc/wireguard
RUN mkdir -p /config
RUN mkdir -p /backup

# Expose port for Wireguard
EXPOSE 51820/udp

COPY run.sh /
USER root

ENTRYPOINT [ "/run.sh" ]
