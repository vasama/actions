ARG UBUNTU_VERSION=24.04

FROM ubuntu:$UBUNTU_VERSION

ARG GCC_VERSION=14
ARG LLVM_VERSION=22

ARG USER_ID=1001
ARG USER_NAME=github

# Install tools needed by install scripts:
RUN apt-get update && apt-get install -y \
	wget

# Install Kitware APT repo:
# RUN wget -O - https://apt.kitware.com/kitware-archive.sh | bash -s

# Install LLVM APT repo:
RUN --mount=type=bind,source=images/ubuntu/add-llvm-apt-repository.sh,target=/tmp/run.sh \
	/tmp/run.sh $LLVM_VERSION

# Install Microsoft APT repo:
RUN --mount=type=bind,source=images/ubuntu/add-microsoft-apt-repository.sh,target=/tmp/run.sh \
	/tmp/run.sh

# Install miscellaneous packages:
RUN apt-get update && apt-get install -y \
	cmake \
	git \
	ninja-build \
	pipx \
	powershell

# Install C++ compilers:
RUN apt-get update && apt-get install -y \
	clang-$LLVM_VERSION \
	clang-format-$LLVM_VERSION \
	clang-tidy-$LLVM_VERSION \
	clang++-$LLVM_VERSION \
	g++-$GCC_VERSION \
	gcc-$GCC_VERSION

# Install Python tools:
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install \
	conan

# Configure default compilers:
RUN --mount=type=bind,source=images/ubuntu/configure-compilers.ps1,target=/tmp/run.ps1 \
	/tmp/run.ps1 -GCC $GCC_VERSION -LLVM $LLVM_VERSION

# Create GitHub runner group and user:
RUN --mount=type=bind,source=images/ubuntu/configure-user.sh,target=/tmp/run.sh \
	/tmp/run.sh $USER_ID $USER_NAME

# Switch to the GitHub user:
USER $USER_ID:$USER_ID

# Configure Conan home directory:
ENV CONAN_HOME="/home/github/.conan2"

# Create default Conan profile:
RUN --mount=type=bind,source=images/ubuntu/configure-conan.ps1,target=/tmp/run.ps1 \
	/tmp/run.ps1 -Architecture x86_64 -GCC $GCC_VERSION -LLVM $LLVM_VERSION

ENTRYPOINT ["pwsh"]
