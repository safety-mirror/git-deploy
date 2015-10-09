load test_helper

setup(){
	mkdir -p /tmp/git-deploy-test
	create_data_volume
}

teardown(){
	rm -rf /tmp/git-deploy-test
	destroy_data_volume
	destroy_container
}

@test "Can build container" {
	run build_container
	[ "$status" -eq 0 ]
}

@test "Can backup and restore a repository" {
	run_container
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_test_commit testrepo
	destroy_container
	run_container
	run clone_repo testrepo
	[ "$status" -eq 0 ]
}

@test "Internal pre-receive hook can reject bad commit" {
	run_container
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
	push_hook testrepo master hooks/pre-receive
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "External pre-receive hook can reject bad commit" {
	run_container
	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	destroy_container
	run_container /git/testhookrepo

	run push_test_commit testrepo badfile
	[ "$status" -eq 0 ]

	push_hook testhookrepo master pre-receive

	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]

	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "External pre-receive hook in branch can reject bad commit" {
	run_container
	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	destroy_container
	run_container /git/testhookrepo

	run push_test_commit testrepo badfile
	[ "$status" -eq 0 ]

	push_hook testhookrepo somebranch pre-receive

    set_config testrepo HOOK_REPO_REF somebranch

	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]

	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "External pre-receive hook can reject bad commit without priming" {
	run_container
	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	destroy_container
	run_container /git/testhookrepo

	push_hook testhookrepo master pre-receive

	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Internal update hook can reject bad commit" {
	run_container
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo master hooks/update
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "External update hook can reject bad commit" {
	run_container
	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	destroy_container
	run_container /git/testhookrepo

	run push_test_commit testrepo badfile
	[ "$status" -eq 0 ]

	push_hook testhookrepo master update

	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]

	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "External update hook in branch can reject bad commit" {
	run_container
	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	destroy_container
	run_container /git/testhookrepo

	run push_test_commit testrepo badfile
	[ "$status" -eq 0 ]

	push_hook testhookrepo somebranch update

    set_config testrepo HOOK_REPO_REF somebranch

	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]

	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Internal post-receive hook can echo text" {
	run_container
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo master hooks/post-receive
	run push_test_commit testrepo somefile
	echo "${lines[5]}" | grep "post-receive success"
}

@test "External post-receive hook can echo text" {
	run_container
	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	destroy_container
	run_container /git/testhookrepo

	push_hook testhookrepo master post-receive
	run push_test_commit testrepo somefile
	echo "${lines[6]}" | grep "post-receive success"
}


@test "External post-receive hook in branch can echo text" {
	run_container
	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	destroy_container
	run_container /git/testhookrepo
	push_hook testhookrepo somebranch post-receive
    set_config testrepo HOOK_REPO_REF somebranch

	run push_test_commit testrepo somefile
	echo "${lines[8]}" | grep "post-receive success"
}

@test "Concurrent pre-receive hooks are sandboxed" {
	run_container
	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	destroy_container
	run_container /git/testhookrepo
	push_hook testhookrepo master pre-receive

	# background push: slowfile will sleep for 5 seconds
	push_test_commit testrepo slowfile &

	# rejected while another pre-receive is firing
	sleep 2
	run push_test_commit testrepo slowfile
	echo $output | grep -i "another git push is in progress"
	[ "$status" -eq 1 ]

	# accepted after pre-receive completes
	sleep 5
	run push_test_commit testrepo slowfile
	[ "$status" -eq 0 ]
}

@test "Sandbox locks expire" {
	run_container
	ssh_command "mkrepo testhookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo
	clone_repo testrepo
	destroy_container
	run_container /git/testhookrepo
	push_hook testhookrepo master pre-receive

	# The hook never finishes, but push times out
	run push_test_commit testrepo stallfile
	[ "$status" -eq 1 ]

	# Subsequent pushes are not blocked
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
}

@test "Generate encryption key" {
	run_container

	run ssh_command "genkey testkey"
	[ "$status" -eq 0 ]
}

@test "Generate encryption key but key already exists" {
	run_container

	ssh_command "genkey testkey"
	run ssh_command "genkey testkey"
	[ "$status" -eq 1 ]
	echo $output | grep -q "already exists"
}

@test "Generate encryption key without name" {
	run_container

	run ssh_command "genkey"
	[ "$status" -eq 1 ]
	echo $output | grep -q "Usage"
}

@test "Generate application secret" {
	run_container
	ssh_command "genkey testkey"

	run ssh_command "secret testkey foo"
	[ "$status" -eq 0 ]
}

@test "Generate application secret from stdin" {
	run_container
	ssh_command "genkey testkey"

	date | ssh_command "secret testkey"
	[ "$?" -eq 0 ]
}

@test "Generate application secret but key not created" {
	run_container

	run ssh_command "secret testkey foo"
	[ "$status" -eq 1 ]
	echo $output | grep "not found"
}

@test "Roundtrip application secret" {
	run_container
	ssh_command "genkey testkey"

	run ssh_command "secret testkey FOO=bar"

	# Reassemble PGP message and decrypt in container
	DECRYPTED=$(echo "-----BEGIN PGP MESSAGE-----

${lines[1]}
-----END PGP MESSAGE-----" | container_command gpg --decrypt)
	echo $DECRYPTED | grep -q "FOO=bar"
}

@test "Log authentication failure" {
	run_container

	# Generate a key that won't work, try to use it:
	ssh-keygen -b 2048 -t rsa -f /tmp/git-deploy-test/badkey -q -N ""
	run ssh \
		-p2222 \
		-i /tmp/git-deploy-test/badkey \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		git@${DOCKER_HOST_IP}

	run docker logs test-git-deploy
	echo ${output} | grep -q "Connection closed by"
}

@test "Log authentication success" {
	run_container
	ssh_command "mkrepo testrepo"

	run docker logs test-git-deploy

	echo ${output} | grep -q "Accepted publickey for git"
}

@test "Log messages from hook" {
	run_container
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo master hooks/pre-receive
	push_test_commit testrepo goodfile
	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
	echo ${output} | grep -q "Rejecting badfile"
	sleep 1

	# Confirm stderr and stdout from the hook are captured:
	run docker logs test-git-deploy
	echo ${output} | grep -q "Accepting goodfile"
	echo ${output} | grep -q "Rejecting badfile"
}