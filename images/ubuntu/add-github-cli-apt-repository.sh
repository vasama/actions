#!/usr/bin/bash

set -euxo pipefail

# Add GitHub CLI APT repository GPG key:
mkdir -p -m 755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

# Add GitHub CLI APT repository:
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
