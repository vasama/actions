#!/usr/bin/bash

set -euxo pipefail

USER_ID="$1"
USER_NAME="$2"

groupadd -g "$USER_ID" "$USER_NAME"
useradd -u "$USER_ID" -g "$USER_ID" "$USER_NAME"

mkdir -p "/home/$USER_NAME"
chown $USER_ID:$USER_ID "/home/$USER_NAME"

echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USER_NAME"
chmod 0440 "/etc/sudoers.d/$USER_NAME"
