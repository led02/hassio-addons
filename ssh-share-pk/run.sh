#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
KEYS_PATH=/data/host_keys

AUTHORIZED_KEYS=$(jq --raw-output ".authorized_keys[]" $CONFIG_PATH)
PASSWORD=$(jq --raw-output ".password" $CONFIG_PATH)

HOSTNAME=$(hostname)

# Init defaults config
sed -i s/#PermitRootLogin.*/PermitRootLogin\ yes/ /etc/ssh/sshd_config
sed -i s/#LogLevel.*/LogLevel\ DEBUG/ /etc/ssh/sshd_config

if [ ! -z "$AUTHORIZED_KEYS" ]; then
    echo "[INFO] Setup authorized_keys"

    mkdir -p ~/.ssh
    while read -r line; do
        echo "$line" >> ~/.ssh/authorized_keys
    done <<< "$AUTHORIZED_KEYS"

    chmod 600 ~/.ssh/authorized_keys
    sed -i s/#PasswordAuthentication.*/PasswordAuthentication\ no/ /etc/ssh/sshd_config
elif [ ! -z "$PASSWORD" ]; then
    echo "[INFO] Setup password login"

    echo "root:$PASSWORD" | chpasswd 2&> /dev/null
    sed -i s/#PasswordAuthentication.*/PasswordAuthentication\ yes/ /etc/ssh/sshd_config
    sed -i s/#PermitEmptyPasswords.*/PermitEmptyPasswords\ no/ /etc/ssh/sshd_config
else
    echo "[Error] You need setup a login!"
    exit 1
fi

# Generate host keys
if [ ! -d "$KEYS_PATH" ]; then
    echo "[INFO] Create host keys"

    mkdir -p "$KEYS_PATH"
    ssh-keygen -A
    cp -fp /etc/ssh/ssh_host* "$KEYS_PATH/"
else
    echo "[INFO] Restore host keys"
    cp -fp "$KEYS_PATH"/* /etc/ssh/
fi

# Generate keypair
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "[INFO] Create keypair"

    mkdir -p ~/.ssh
    ssh-keygen -t rsa -f ~/.ssh/id_rsa

    mkdir -p /share/ssh
    cp -fp ~/.ssh/id_rsa.pub /share/ssh/$HOSTNAME
fi

# Persist shell history by redirecting .ash_history to /data
touch /data/.ash_history
chmod 600 /data/.ash_history
ln -s -f /data/.ash_history /root/.ash_history

# start server
exec /usr/sbin/sshd -D -e < /dev/null
