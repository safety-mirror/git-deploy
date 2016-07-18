#!/bin/bash

source /test/test_helper.bash

set -e

setup

docker ps
docker network ls

echo "test ssh to git-deploy-test"
ssh -p 2222 \
	-a \
	-i "test-keys/test-sshkey" \
	-o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	git@git-deploy-test \
	"user"

echo "test ssh to git-deploy-test-exthooks"
ssh \
	-p 2222 \
	-a \
	-i "test-keys/test-sshkey" \
	-o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	git@git-deploy-test-exthooks \
	"user"

echo "test ssh to git-deploy-test-exthooks-sig"
ssh \
	-p 2222 \
	-a \
	-i "test-keys/test-sshkey" \
	-o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	git@git-deploy-test-exthooks-sig \
	"user"

teardown


setup

set_container "git-deploy-test-exthooks-sig"

make_hook_repo

clone_repo testhookrepo "git-deploy-test"
ssh_command "mkrepo testrepo"
clone_repo testrepo

push_hook testhookrepo master hooks/pre-receive 94F94EC1
push_test_commit testrepo

push_hook testhookrepo master hooks/update
push_test_commit testrepo || exit 0

push_hook testhookrepo master hooks/post-receive 9BE4FBEC
push_test_commit testrepo || exit 0


teardown
