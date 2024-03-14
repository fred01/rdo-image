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
    openssh-server autossh \
    # VCS \
    git subversion subversion-tools mercurial \
    # Database clients \
    mysql-client postgresql-client jq redis-tools \
    # C/C++ \
    build-essential cmake g++ m4 \
    # R \
    r-base r-base-dev \
    # TeX \
    texlive \
    # JVM \
    openjdk-8-jre-headless openjdk-11-jdk-headless openjdk-17-jdk-headless maven ant clojure scala \
    # Python 3 \
    python3-matplotlib python3-numpy python3-pip python3-scipy python3-pandas python3-dev pipenv \
    # Python 2 \
    python2-dev python2-pip-whl \
    # Ruby \
    ruby-full \
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

## Mongodb shell
RUN set -ex -o pipefail &&  \
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | tee /etc/apt/trusted.gpg.d/server-7.0.asc && \
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && apt-get install -y mongodb-mongosh

## PHP
RUN set -ex -o pipefail && \
    add-apt-repository ppa:ondrej/php -y && \
    apt-get install -y --no-install-recommends php8.0-cli php8.0-common php8.0-curl php8.0-xml php8.0-mbstring && \
    wget https://github.com/composer/composer/releases/download/2.2.1/composer.phar -O /usr/bin/composer -q && \
    chmod +x /usr/bin/composer

## dotNet
RUN if [ "$TARGETARCH" == "arm64" ] ; \
    then echo "Skipping installation of .NET packages, as they are only available for arm64 starting from Ubuntu 23.04+" ; \
    else set -ex -o pipefail && \
    wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-sdk-8.0 ; \
    fi

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
    kubectl version --client && \
    # aws-cli \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$AWS_TOOLS_ARCH.zip" -o /tmp/awscliv2.zip && \
    mkdir -p /tmp/aws.extracted && \
    unzip -q /tmp/awscliv2.zip -d /tmp/aws.extracted && \
    /tmp/aws.extracted/aws/install && \
    rm -rf /tmp/aws.extracted /tmp/awscliv2.zip && \
    /usr/local/bin/aws --version && \
    # gcloud \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && apt-get install -y google-cloud-sdk && \
    gcloud --version && \
    # rclone \
    curl -fsSL https://downloads.rclone.org/v1.56.2/rclone-v1.56.2-linux-$TARGETARCH.zip -o /tmp/rclone.zip && \
    mkdir -p /tmp/rclone.extracted && unzip -q /tmp/rclone.zip -d /tmp/rclone.extraced && \
    install -g root -o root -m 0755 -v /tmp/rclone.extraced/*/rclone /usr/local/bin && \
    rm -rf /tmp/rclone.extraced /tmp/rclone.zip && \
    rclone --version

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
    ruby --version && \
    echo "" && \
    php -v && \
    composer -V && \
    echo "" && \
    docker --version &&  \
    docker compose version && \
    echo "" && \
    echo "Kubectl: $(kubectl version --client)" && \
    echo "" && \
    gcloud --version && \
    echo "" && \
    rclone --version && \
    echo "############################### Versions #####################################"
