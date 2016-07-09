#!/bin/bash

source test_helper.bash

rm -rf /tmp/git-deploy-test
mkdir -p /tmp/git-deploy-test
destroy_backups
reset_container

echo "starting test"

	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	reset_container /git/testhookrepo

	push_test_commit testrepo badfile

echo "exit code: $?"
