#!/bin/sh
# Install deploy-sync on an app host: sh install.sh  (run as root from a checkout of this repo)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
command -v age >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -q age
install -d -m 700 /etc/deploy-sync
[ -f /etc/deploy-sync/age.key ] || age-keygen -o /etc/deploy-sync/age.key 2>/dev/null
chmod 600 /etc/deploy-sync/age.key
install -m 755 "$here/deploy-sync" /usr/local/bin/deploy-sync
install -m 755 "$here/deploy-release" /usr/local/bin/deploy-release
install -m 644 "$here/deploy-sync.service" "$here/deploy-sync.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now deploy-sync.timer
echo "age public key of $(hostname): $(age-keygen -y /etc/deploy-sync/age.key)"
