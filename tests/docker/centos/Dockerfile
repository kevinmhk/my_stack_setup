FROM quay.io/centos/centos:stream9

RUN dnf -y update \
  && dnf -y install --allowerasing \
    ca-certificates \
    curl-minimal \
    file \
    findutils \
    gcc \
    gcc-c++ \
    git \
    glibc-devel \
    make \
    openssl-devel \
    perl \
    procps-ng \
    python3 \
    sudo \
    tar \
    which \
    xz \
    zlib-devel \
    bzip2 \
    gzip \
  && dnf clean all

RUN useradd -m -s /bin/bash tester \
  && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester/app

COPY --chown=tester:tester . /home/tester/app

CMD ["bash", "-lc", "scripts/setup.sh && tests/assert.sh"]
