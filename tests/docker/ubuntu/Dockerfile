FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    bzip2 \
    ca-certificates \
    curl \
    file \
    gpg \
    git \
    locales \
    make \
    perl \
    procps \
    python3 \
    sudo \
    tar \
    xz-utils \
    gcc \
    g++ \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash tester \
  && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester/app

COPY --chown=tester:tester . /home/tester/app

CMD ["bash", "-lc", "scripts/setup.sh && tests/assert.sh"]
