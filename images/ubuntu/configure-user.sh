#!/usr/bin/bash

set -eux

USER_ID="$1"
USER_NAME="$2"

groupadd -g "$USER_ID" "$USER_NAME"
useradd -u "$USER_ID" -g "$USER_ID" -d "/github/home" "$USER_NAME"

mkdir -p "/github/home"
chown $USER_ID:$USER_ID "/github/home/"
