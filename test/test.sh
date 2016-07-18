#!/bin/bash

source /test/test_helper.bash

setup

docker ps
docker network ls



ssh -p 2222 \
	-a \
	-vvvv \
	-i "test-keys/test-sshkey" \
	-o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	git@git-deploy-test \
	"user"

ssh \
	-p 2222 \
	-a \
	-vvvv \
	-i "test-keys/test-sshkey" \
	-o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	git@git-deploy-test-exthooks \
	"user"

ssh \
	-p 2222 \
	-a \
	-vvvv \
	-i "test-keys/test-sshkey" \
	-o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	git@git-deploy-test-exthooks-sig \
	"user"



teardown
