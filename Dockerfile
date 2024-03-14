FROM ubuntu:22.04

ENV LANG=C.UTF-8

LABEL maintainer="Alexander Sedov <alexander.sedov@jetbrains.com>"

ARG TARGETARCH

ARG KUBECTL_VERSION=1.28

# Support various rvm, nvm etc stuff which requires executing profile scripts (-l)
SHELL ["/bin/bash", "-lc"]
CMD ["/bin/bash", "-l"]

# Set debconf to run non-interactively
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update && apt-get install -y apt-utils apt-transport-https software-properties-common

# Newest git
RUN apt-add-repository ppa:git-core/ppa -y && apt-get update

RUN set -ex -o pipefail && apt-get install -y \
    # Useful utilities \
    curl unzip wget socat man-db rsync moreutils vim lsof \
    # SSH related \
    openssh-server \
    # VCS \
    git \
    # Database clients \
    jq \
    # C/C++ \
    build-essential cmake g++ m4 \
    # JVM \
    openjdk-8-jre-headless openjdk-11-jdk-headless openjdk-17-jdk-headless maven ant clojure scala \
    # Python 3 \
    python3-matplotlib python3-numpy python3-pip python3-scipy python3-pandas python3-dev pipenv \
    # Python 2 \
    python2-dev python2-pip-whl \
    && \
    # Setup Java \
    update-alternatives --get-selections | grep usr/lib/jvm | awk '{print $1}' | \
    grep -v jpackage | grep -v jexec | \
    while IFS= read line; do echo $line; update-alternatives --set $line /usr/lib/jvm/java-11-openjdk-$TARGETARCH/bin/$line; done && \
    java -version && javac -version && \
    # Prepare SSH \
    mkdir -p /run/sshd && \
    # Check Python \
    python3 --version && python2 --version && pip3 --version && \
    # Go \
    curl  -fsSL "https://dl.google.com/go/$(curl -fsSL https://go.dev/dl/?mode=json | jq -r  'map(select(.stable == true)) | max_by(.version) | .files[] | select(.arch == "'$TARGETARCH'" and .os == "linux") | .filename' )" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz && \
    for x in /usr/local/go/bin/*; do echo $x; ln -vs $x /usr/local/bin/$(basename $x); done && ls -la /usr/local/bin && go version


ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-$TARGETARCH

## Nodejs, npm, yarn
RUN set -ex -o pipefail &&  \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
	curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null && \
	echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | tee /etc/apt/sources.list.d/yarn.list && \
	apt-get update && apt-get install -y nodejs yarn

### Cloud Tools
## Docker
RUN DOCKER_VERSION_STRING="5:24.0.9-1~ubuntu.22.04~jammy"; \
    set -ex -o pipefail && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y docker-ce=$DOCKER_VERSION_STRING docker-ce-cli=$DOCKER_VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin

## The awscli tools use a different naming scheme for arm64 builds
RUN if [ "$TARGETARCH" == "arm64" ] ; \
        then AWS_TOOLS_ARCH=aarch64 ; \
        else AWS_TOOLS_ARCH=x86_64 ; \
    fi && \
    set -ex -o pipefail && \
    # Kubernetes \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBECTL_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
    mkdir -p /etc/apt/keyrings/ && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBECTL_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    apt-get update && apt-get install -y kubectl && \
    kubectl version --client

RUN echo "############################### Versions #####################################" && \
    java -version &&  \
    javac -version && \
    echo "" && \
    python3 --version &&  \
    python2 --version &&  \
    pip3 --version && \
    echo "" && \
    go version && \
    echo "" && \
    echo ".NET SDK" && \
    if [ "$TARGETARCH" != "arm64" ] ; then dotnet --list-sdks ; else echo "Not available for arm64" ; fi && \
    echo "" && \
    echo ".NET Runtimes" && \
    if [ "$TARGETARCH" != "arm64" ] ; then dotnet --list-runtimes ; else echo "Not available for arm64" ; fi && \
    echo "" && \
    echo "Nodejs: $(node --version)" &&  \
    echo "Npm: $(npm --version)" &&  \
    echo "Yarn: $(yarn --version)" && \
    echo "" && \
    composer -V && \
    echo "" && \
    docker --version &&  \
    docker compose version && \
    echo "" && \
    echo "Kubectl: $(kubectl version --client)" && \
    echo "" && \
    echo "############################### Versions #####################################"
