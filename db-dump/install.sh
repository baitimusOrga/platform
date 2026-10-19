#!/bin/sh
# Install db-dump on an app host: sh install.sh  (as root, from a checkout of this repo)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
install -m 755 "$here/db-dump" /usr/local/bin/db-dump
install -m 644 "$here/db-dump.service" "$here/db-dump.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now db-dump.timer
