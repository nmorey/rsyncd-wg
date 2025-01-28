#!/bin/bash -ex

# Start Wireguard
wg-quick up /config/wg0.conf

# Start rsync
rsync --daemon --no-detach -v --config=/config/rsyncd.conf
