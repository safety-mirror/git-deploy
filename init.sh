#!/bin/bash

restore

mkdir -p /git/.ssh/host_keys
for TYPE in rsa dsa ecdsa ed25519; do
    if [ ! -f "/git/.ssh/host_keys/ssh_host_${TYPE}_key" ]; then
        echo -n "Generating SSH ${TYPE} Host Key..."
        ssh-keygen -N '' -qt ${TYPE} -f /git/.ssh/host_keys/ssh_host_${TYPE}_key
        echo " Done"
    fi
done

backup

rm /git/.profile
for LINE in `env`; do
    echo "export $LINE" >> ~/.profile;
done

echo "Starting Git-Deploy on port $PORT"
/usr/sbin/sshd -D -p $PORT
