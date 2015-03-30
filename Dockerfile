FROM debian:jessie

RUN apt-get update && \
    LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y \
      awscli \
      openssh-server \
      sharutils \
      vim-nox \
      git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN useradd -m -d /git -s /usr/bin/git-shell git
RUN usermod -p `dd if=/dev/urandom bs=1 count=30 | uuencode -m - | head -2 | tail -1` git
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
RUN echo "UsePrivilegeSeparation no" >> /etc/ssh/sshd_config
RUN mkdir /var/run/sshd
RUN chown -R git /etc/ssh

ADD mkrepo.sh /usr/bin/mkrepo
RUN chmod +x /usr/bin/mkrepo

EXPOSE 2222

WORKDIR /git

USER git

CMD ["/usr/sbin/sshd","-D","-p","2222"]
