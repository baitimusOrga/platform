#!/bin/sh
# Install deploy-sync on an app host: sh install.sh  (run as root from a checkout of this repo)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
install -m 755 "$here/deploy-sync" /usr/local/bin/deploy-sync
install -m 755 "$here/deploy-release" /usr/local/bin/deploy-release
install -m 644 "$here/deploy-sync.service" "$here/deploy-sync.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now deploy-sync.timer
