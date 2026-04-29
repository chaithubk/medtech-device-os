FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install essential tools first
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    ca-certificates \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install Yocto build dependencies
RUN apt-get update && apt-get install -y \
    gawk \
    wget \
    git \
    file \
    lz4 \
    diffstat \
    unzip \
    texinfo \
    gcc \
    build-essential \
    chrpath \
    socat \
    cpio \
    python3 \
    python3-pip \
    python3-pexpect \
    autoconf \
    automake \
    libtool \
    pkg-config \
    gettext \
    patch \
    perl \
    bison \
    flex \
    gperf \
    xz-utils \
    debianutils \
    iputils-ping \
    xterm \
    screen \
    tmux \
    curl \
    vim \
    nano \
    openssh-client \
    openssh-server \
    qemu-system-arm \
    qemu-system-x86-64 \
    qemu-user-static \
    qemu-utils \
    reprepro \
    graphviz \
    ca-certificates \
    locales \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install required Python packages
RUN pip3 install --upgrade pip setuptools wheel
RUN pip3 install \
    pyyaml \
    requests \
    jinja2 \
    pytest

# Create workspace
WORKDIR /workspace

# Create an unprivileged user for BitBake (Yocto refuses root builds).
RUN useradd -m -s /bin/bash builder

# Set git safe directory (for dev container)
RUN git config --global --add safe.directory /workspace

CMD ["/bin/bash"]
