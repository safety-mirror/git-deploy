#!/bin/bash

source test/test_helper.bash

prepare_environment
build_container
create_data_volume
run_container
gen_sshkey
import_sshkey
ssh_command "backup"
ssh_command "mkrepo testrepo"
clone_repo testrepo

push_hook testrepo pre-receive
push_test_commit testrepo goodfile
push_test_commit testrepo badfile

push_hook testrepo update

push_test_commit testrepo goodfile
push_test_commit testrepo badfile


push_hook testrepo post-commit
push_test_commit testrepo goodfile > /tmp/somefile 2>&1

cat /tmp/somefile | sed -ne 19p
