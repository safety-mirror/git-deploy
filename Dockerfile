FROM debian:jessie

RUN apt-get update && \
    LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y \
    duplicity \
    openssh-server \
    git \
    curl \
    jq \
    python-pip \
    python-dev && \
    apt-get clean
RUN pip install awscli boto virtualenv
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN useradd -m -d /git -s /usr/bin/git-shell git
RUN usermod -p $(od -An -N20 -v -w20 -tx1 /dev/urandom | tr -d ' ') git

RUN mkdir -p /var/run/sshd
RUN echo "HostKey /git/.ssh/host_keys/ssh_host_rsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey /git/.ssh/host_keys/ssh_host_dsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey /git/.ssh/host_keys/ssh_host_ecdsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey /git/.ssh/host_keys/ssh_host_ed25519_key" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "UsePrivilegeSeparation no" >> /etc/ssh/sshd_config

RUN mkdir -p /backup_volume 
RUN chown -R git:git /backup_volume

ENV PORT=2222
ENV PATH=/git/bin:/git/git-shell-commands:/opt/git-deploy/bin:$PATH

RUN echo "Git-Deploy Shell" > /etc/motd

EXPOSE $PORT

WORKDIR /git

ADD bin /opt/git-deploy/bin/
RUN mkdir git-shell-commands && ln -s /opt/git-deploy/bin/* git-shell-commands/
ADD init.sh /init.sh
RUN chown -R git: /git/

VOLUME /git

USER git

CMD ["bash","/init.sh"]
