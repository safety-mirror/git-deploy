FROM debian:jessie

RUN apt-get update && \
    LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y \
      openssh-server \
      sharutils \
      awscli \
      groff \
      vim-nox \
      curl \
      python-pip \
      git && \
    pip install boto && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


ADD git-shell-commands /git/git-shell-commands/

RUN useradd -m -d /git -s /usr/bin/git-shell git
RUN mkdir /git/.ssh
RUN usermod -p `dd if=/dev/urandom bs=1 count=30 | uuencode -m - | head -2 | tail -1` git
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
RUN echo "UsePrivilegeSeparation no" >> /etc/ssh/sshd_config
RUN mkdir /var/run/sshd
RUN chown -R git /etc/ssh
RUN chown -R git: /git/

EXPOSE 2222

WORKDIR /git

USER git

CMD bash /git/git-shell-commands/restore && /usr/sbin/sshd -D -p 2222
