FROM gliderlabs/alpine

RUN apk --update add bash duplicity openssh git curl

RUN adduser -D -h /git -s /usr/bin/git-shell git
RUN echo "git:$(od -An -N20 -v -w20 -tx1 /dev/urandom | tr -d ' ')" | chpasswd

RUN mkdir /var/run/sshd
RUN echo "HostKey /git/.ssh/host_keys/ssh_host_rsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey /git/.ssh/host_keys/ssh_host_dsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey /git/.ssh/host_keys/ssh_host_ecdsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey /git/.ssh/host_keys/ssh_host_ed25519_key" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "UsePrivilegeSeparation no" >> /etc/ssh/sshd_config

ENV PORT=2222
ENV PATH=/git/bin:/git/git-shell-commands:$PATH

RUN echo "Git-Deploy Shell" > /etc/motd

EXPOSE $PORT

WORKDIR /git

ADD git-shell-commands /git/git-shell-commands/
ADD bin /usr/local/bin/
ADD init.sh /init.sh
RUN chown -R git: /git/

USER git

CMD ["bash","/init.sh"]
