#!/bin/bash

source /test/test_helper.bash

setup

docker ps

key=${2-"test-keys/test-sshkey"}
ssh \
	-p 2222 \
	-a \
	-vvvv \
	-i $key \
	-o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	git@${CONTAINER} \
	"user"

teardown
