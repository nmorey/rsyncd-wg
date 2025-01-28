# rsyncd-wg

A minimalist image with rsync daemon and a wireguard interface.
Its intended usage is to deploy a "safe" remote backup target.
Safe in that case means that if the source server is hacked, access to the backups can be gained but no other access to the Docker server.
Because there is no SSH, and no open port but for Wireguard, the attack surface is as small as possible and the risk limited if hacked.

# Usage

```bash
$ docker run nmorey/rsyncd-wg -p 51820:51820/udp -v /path/to/config:/config -v /path/to/backup:/backup --cap-add=NET_ADMIN
```

The command above spins up a container that will listen on port 51820 for Wireguard connections. Syncing files is then as easy as `RSYNC_PASSWORD=<rsyncuser passwd> rsync -aPh <file-or-directory> rsync://rsyncuser:10.6.0.2/backup`.

# Configuration

/path/to/config must contain:
- A wg0.conf file for Wireguard.
  A template is provided in config/. It just requires its PrivateKey to be setup and the Peer PublicKey
- A rsyncd.conf file
  The default file should work wihtout any changes
- A rsync.secrets file
  A password needs to be set for rsyncuser in the template file.
