#!/usr/bin/bash

set -eux

cd /tmp

source /etc/os-release

# Download Microsoft APT repository deb package:
wget -q "https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb"

# Install Microsoft APT repository:
dpkg -i packages-microsoft-prod.deb

rm packages-microsoft-prod.deb
