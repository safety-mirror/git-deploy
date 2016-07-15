load test_helper

setup(){
	rm -rf /tmp/git-deploy-test
	mkdir -p /tmp/git-deploy-test
	reset_container
	destroy_backups
	set_container "git-deploy-test"
}

teardown(){
    rm -rf /tmp/git-deploy-test
}

@test "Can resolve ssh-key to username" {
	run ssh_command "user"
	echo "${output}" | grep "testuser"
}

@test "Can backup and restore a repository" {
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_test_commit testrepo
	reset_container
	run clone_repo testrepo
	[ "$status" -eq 0 ]
}

@test "Reject if HOOK_REPO_VERIFY and no known signature on HOOK_REPO" {
    set_container "git-deploy-test-exthooks-sig"

    make_hook_repo

	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo

	push_hook testhookrepo master hooks/pre-receive 94F94EC1
	run push_test_commit testrepo
	[ "$status" -eq 0 ]

	push_hook testhookrepo master hooks/update
	run push_test_commit testrepo
	[ "$status" -eq 1 ]

	push_hook testhookrepo master hooks/post-receive 9BE4FBEC
	run push_test_commit testrepo 
	[ "$status" -eq 1 ]
}

@test "Internal pre-receive hook can reject bad commit" {
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

@test "Internal pre-receive hook ignored if HOOK_REPO is defined" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo master hooks/pre-receive
	run push_test_commit testrepo badfile
	[ "$status" -eq 0 ]
}

@test "External pre-receive hook can reject bad commit" {
    set_container "git-deploy-test-exthooks"

	make_hook_repo testhookrepo
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo "git-deploy-test"
	clone_repo testrepo

	run push_test_commit testrepo badfile
	[ "$status" -eq 0 ]

	push_hook testhookrepo master pre-receive

	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]

	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "External pre-receive hook in branch can reject bad commit" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo testhookrepo
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo "git-deploy-test"
	clone_repo testrepo

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
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"

	ssh_command "mkrepo testrepo"
	clone_repo testrepo

	push_hook testhookrepo master pre-receive

	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Internal update hook can reject bad commit" {
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo master hooks/update
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "External update hook can reject bad commit" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo

	run push_test_commit testrepo badfile
	[ "$status" -eq 0 ]

	push_hook testhookrepo master update

	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]

	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "External update hook in branch can reject bad commit" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo

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
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo master hooks/post-receive
	run push_test_commit testrepo somefile
	echo "${output}" | grep "post-receive success"
}

@test "External post-receive hook can echo text" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo

	push_hook testhookrepo master post-receive
	run push_test_commit testrepo somefile
	echo "${output}" | grep "post-receive success"
}


@test "External post-receive hook in branch can echo text" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testhookrepo somebranch post-receive
	set_config testrepo HOOK_REPO_REF somebranch

	run push_test_commit testrepo somefile
	echo "${output}" | grep "post-receive success"
}

@test "Concurrent pre-receive hooks are sandboxed" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
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
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testhookrepo master pre-receive

	# The hook never finishes, but push times out
	run push_test_commit testrepo stallfile
	[ "$status" -eq 1 ]

	# Subsequent pushes are not blocked
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
}

@test "Generate encryption key" {
	run ssh_command "genkey testkey"
	[ "$status" -eq 0 ]
}

@test "Generate encryption key but key already exists" {
	ssh_command "genkey testkey"
	run ssh_command "genkey testkey"
	[ "$status" -eq 1 ]
	echo $output | grep -q "already exists"
}

@test "Generate encryption key without name" {
	run ssh_command "genkey"
	[ "$status" -eq 1 ]
	echo $output | grep -q "Usage"
}

@test "Generate encryption key callback" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testhookrepo somebranch post-generate-key
	set_config testrepo HOOK_REPO_REF somebranch

	# Commit a file to prime the hook repo
	run push_test_commit testrepo somefile

	run ssh_command "genkey testkey"
	[ "$status" -eq 0 ]
	echo $output | grep -q "post-generate-key success"
}

@test "Generate application secret" {
	ssh_command "genkey testkey"

	run ssh_command "secret testkey foo"
	[ "$status" -eq 0 ]
}

@test "Generate application secret from stdin" {
	ssh_command "genkey testkey"

	date | ssh_command "secret testkey"
	[ "$?" -eq 0 ]
}

@test "Generate application secret but key not created" {
	run ssh_command "secret testkey foo"
	[ "$status" -eq 1 ]
	echo $output | grep "not found"
}

@test "Roundtrip application secret" {
	ssh_command "genkey testkey"

	run ssh_command "secret testkey FOO=bar"

	# Reassemble PGP message and decrypt in container
	DECRYPTED=$(echo "-----BEGIN PGP MESSAGE-----

${lines[1]}
-----END PGP MESSAGE-----" | container_command "gpg --decrypt")
	echo $DECRYPTED | grep -q "FOO=bar"
}

@test "Log authentication failure" {

	# Generate a key that won't work, try to use it:
	ssh-keygen -b 2048 -t rsa -f /tmp/git-deploy-test/badkey -q -N ""
	run ssh \
		-p2222 \
		-i /tmp/git-deploy-test/badkey \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		git@git-deploy

	run docker logs gitdeploy_git-deploy_1
	echo ${output} | grep -q "Connection closed by"
}

@test "Log authentication success" {
	ssh_command "mkrepo testrepo"

	run docker logs gitdeploy_git-deploy_1

	echo ${output} | grep -q "Accepted publickey for git"
}

@test "Log messages from hook" {
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo master hooks/pre-receive
	push_test_commit testrepo goodfile
	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
	echo ${output} | grep -q "Rejecting badfile"
	sleep 1

	# Confirm stderr and stdout from the hook are captured:
	run docker logs gitdeploy_git-deploy_1
	echo ${output} | grep -q "Accepting goodfile"
	echo ${output} | grep -q "Rejecting badfile"
}

@test "ssh key validation fails with a bad key" {
	key=$(cat test-keys/test-sshkey.pub | cut -b 512-)
	command="ssh-key badkey '${key}'"
	run ssh_command "$command"
	[ $status -eq 1 ]
}

@test "Adding an ssh key for a user" {
	key=$(cat test-keys/test-sshkey.pub)
	command="ssh-key testuser ${key}"
	run ssh_command "$command"
	[ $status -eq 0 ]
}

@test "Added keys can be used for login successfully" {
	key=$(cat test-keys/test-sshkey2.pub)
	reset_container
	command="ssh-key testuser2 ${key}"
	run ssh_command "$command"
	[ $status -eq 0 ]

	run ssh_command "user" test-keys/test-sshkey2
	[ $status -eq 0 ]
}

@test "Run script from hook dir" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testhookrepo master bin/hello

	ssh_command "hookpull testrepo"
	run ssh_command "run testrepo hello World"
	[ $status -eq 0 ]
	echo ${output} | grep -q "Hello World"
}

@test "Run script from hook dir - quotes" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testhookrepo master bin/hello

	ssh_command "hookpull testrepo"
	run ssh_command "run testrepo hello 'from the other side' 'from the outside'"
	[ $status -eq 0 ]
	echo ${output} | grep -q "Hello from the other side"
	echo ${output} | grep -q "Hi from the outside"
}

@test "Run script from hook dir - config.env" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testhookrepo master bin/hello
	push_hook testrepo master config.env

	# Pull isn't required as the push to "testrepo" already pulled.
	run ssh_command "run testrepo hello World"
	[ $status -eq 0 ]
	echo ${output} | grep -q "Hello World"
	echo ${output} | grep -q "From testrepo"
}

@test "Run script from hook dir - not found" {
	ssh_command "mkrepo testrepo"

	run ssh_command "run testrepo hello World"
	[ $status -eq 1 ]
}

@test "Run script from hook dir - no pull" {
    set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testhookrepo master bin/hello

	run ssh_command "run testrepo hello World"
	[ $status -eq 1 ]
}
