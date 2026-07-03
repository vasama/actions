#!/usr/bin/bash

set -eux

source /etc/os-release

echo "UBUNTU_CODENAME=${UBUNTU_CODENAME}"

# Add LLVM APT repository GPG key:
wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc

# Add LLVM APT repository:
echo "deb http://apt.llvm.org/${UBUNTU_CODENAME}/  llvm-toolchain-${UBUNTU_CODENAME}-$1 main" > /etc/apt/sources.list.d/apt.llvm.org.list
