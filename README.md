# Secure Backup Container

This project provides a Dockerized secure backup solution using `rsync` over WireGuard.

## How it works

The container runs an `rsync` daemon that is only accessible through a WireGuard tunnel. The user connects to the container using a WireGuard client, and then can use `rsync` to transfer files to the backup server.

The container is designed to be secure and isolated:
- The `rsync` daemon is the only service exposed over the WireGuard tunnel.
- The user cannot get a shell on the container.
- The WireGuard server public key is generated on the first run.
- The `rsync` password and the client's WireGuard public key are configurable through environment variables.

## How to use

### 1. Build the Docker image

```bash
docker build -t secure-backup .
```

### 2. Run the Docker container

You need to provide an environment variable when running the container:

- `RSYNC_PASSWORD`: The password you want to use for `rsync` authentication.

For persistent WireGuard keys and data, you should create directories on your host machine and mount them as volumes.

```bash
# Create directories on the host
mkdir -p ./wireguard-keys
mkdir -p ./backup-data

# Run the container with volumes
docker run -d --cap-add=NET_ADMIN --cap-add=SYS_MODULE -p 51820:51820/udp \
  -v $(pwd)/wireguard-keys:/etc/wireguard \
  -v $(pwd)/backup-data:/data/backups \
  -e RSYNC_PASSWORD="<your_rsync_password>" \
  --name secure-backup-container \
  secure-backup
```

**Notes:**
- The `--cap-add=NET_ADMIN --cap-add=SYS_MODULE` capabilities are required for WireGuard to work.
- Mounting `./wireguard-keys` to `/etc/wireguard` ensures that the server's WireGuard keys and configuration are persisted across container restarts.
- Mounting `./backup-data` to `/data/backups` ensures that your backed-up data is stored on the host and not lost if the container is removed.


### 3. Get the server's public key and configure the client

The first time you run the container, it will generate a new WireGuard key pair for the server and print the public key to the logs. You need this public key to configure your WireGuard client. It will also create a default `wg0.conf` file.

```bash
docker logs secure-backup-container
```

You will see an output like this:

```
====================================================
Dumping public server key to the logs:
<server_public_key>
====================================================
Please edit /etc/wireguard/wg0.conf to add your client's public key
```

You need to edit the `wg0.conf` file on the host machine (in the `./wireguard-keys` directory) and add your client's public key to the `[Peer]` section.

Example `wg0.conf`:
```
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <server_private_key_will_be_here>

[Peer]
PublicKey = <your_client_public_key>
AllowedIPs = 10.0.0.2/32
```

### 4. Configure your WireGuard client

Configure your WireGuard client to connect to the container. Here is an example client configuration:

```

```
[Interface]
PrivateKey = <your_client_private_key>
Address = 10.0.0.2/32

[Peer]
PublicKey = <server_public_key>
Endpoint = <your_server_ip>:51820
AllowedIPs = 10.0.0.1/32
PersistentKeepalive = 25
```

Replace `<your_client_private_key>` with your client's private key, `<server_public_key>` with the public key you got from the container's logs, and `<your_server_ip>` with the IP address of the server where the container is running.

### 5. Use rsync to connect to the backup server

Once you are connected to the WireGuard tunnel, you can use `rsync` to transfer files to the backup server.

You will need to create a password file on your client machine with the `rsync` password you set in the `RSYNC_PASSWORD` environment variable.

```bash
echo "<your_rsync_password>" > ~/.rsync-password
chmod 600 ~/.rsync-password
```

Now you can use `rsync` to transfer files:

```bash
rsync -av --password-file=~/.rsync-password /path/to/your/files/ backupuser@10.0.0.1::backups
```

This will transfer the files from `/path/to/your/files/` on your local machine to the `/data/backups` directory inside the container.
