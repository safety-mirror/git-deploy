load test_helper

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

#@test "Concurrent pre-receive hooks are sandboxed" {
#	set_container "git-deploy-test-exthooks"
#	make_hook_repo
#	clone_repo testhookrepo "git-deploy-test"
#	ssh_command "mkrepo testrepo"
#	clone_repo testrepo
#	push_hook testhookrepo master pre-receive
#
#	# background push: slowfile will sleep for 5 seconds
#	push_test_commit testrepo slowfile &
#
#	# rejected while another pre-receive is firing
#	sleep 2
#	run push_test_commit testrepo slowfile
#	echo $output | grep -i "another git push is in progress"
#	[ "$status" -eq 1 ]
#
#	# accepted after pre-receive completes
#	sleep 5
#	run push_test_commit testrepo slowfile
#	[ "$status" -eq 0 ]
#}

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

	make_hook_repo testhookrepo
	ssh_command "mkrepo testrepo"
	clone_repo testhookrepo "git-deploy-test"
	clone_repo testrepo

	push_hook testhookrepo master post-generate-key

	ssh_command "hookpull testrepo"
	run ssh_command "genkey testkey testrepo"
	[ $status -eq 0 ]
	echo ${output} | grep -q "post-generate-key success"
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
		git@git-deploy-test

	run docker logs git-deploy-test
	echo ${output} | grep -q "Connection closed by"
}

@test "Log authentication success" {
	ssh_command "mkrepo testrepo"

	run docker logs git-deploy-test

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
	run docker logs git-deploy-test
	echo ${output} | grep -q "Accepting goodfile"
	echo ${output} | grep -q "Rejecting badfile"
}

@test "SSH key validation fails with a bad key" {
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
	ssh_command "ssh-key testuser2 ${key}"

	run ssh_command "user" test-keys/test-sshkey2
	[ $status -eq 0 ]
	echo ${output} | grep -q "testuser2"
}

@test "Added keys do not overwrite" {
	key=$(cat test-keys/test-sshkey2.pub)
	reset_container
	ssh_command "ssh-key testuser2 ${key}"
	ssh_command "ssh-key testuser3 ${key}"

	run ssh_command "user" test-keys/test-sshkey2
	[ $status -eq 0 ]
	echo ${output} | grep -q "testuser2"
}

@test "Added keys upgrade" {
	key=$(cat test-keys/test-sshkey2.pub)
	docker cp test-keys/test-sshkey2.pub git-deploy-test:/git/.ssh/authorized_keys
	docker exec --user=root git-deploy-test chown git:git /git/.ssh/authorized_keys

	# SSH works, but doesn't have a user:
	run ssh_command "user" test-keys/test-sshkey2
	[ $status -eq 0 ]
	echo $output | grep -qv "testuser"

	# User is added:
	ssh_command "ssh-key testuser2 ${key}" test-keys/test-sshkey2

	# SSH still works, now has a user:
	run ssh_command "user" test-keys/test-sshkey2
	[ $status -eq 0 ]
	echo $output | grep -q "testuser2"
}

@test "User rejected from editing root dir files if not in ADMIN_USERS" {
	key=$(cat test-keys/test-sshkey.pub)
	reset_container
	ssh_command "ssh-key testuser ${key}"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	run set_config testrepo ADMIN_USERS "adminuser"
	[ $status -eq 0 ]

	run set_config testrepo SOMEKEY "someval"
	[ $status -eq 1 ]

	run push_hook testrepo master testfile
	[ $status -eq 1 ]
}

@test "User allowed to edit root dir files if in ADMIN_USERS" {
	key=$(cat test-keys/test-sshkey.pub)
	reset_container
	ssh_command "ssh-key testuser ${key}"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	run set_config testrepo ADMIN_USERS "someuser someuser2 testuser"
	[ $status -eq 0 ]

	run set_config testrepo SOMEKEY "someval"
	[ $status -eq 0 ]

	run push_hook testrepo master testfile
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

@test "Run script from hook dir - pipes" {
	set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testhookrepo master bin/hello

	ssh_command "hookpull testrepo"
	run ssh_command "run testrepo hello World |"
	[ $status -eq 0 ]
	echo ${output} | grep -q "Hello World \|"
	echo ${output} | grep -q "User testuser"
}

@test "Run script from hook dir - config.env" {
	set_container "git-deploy-test-exthooks"
	make_hook_repo
	clone_repo testhookrepo "git-deploy-test"
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testhookrepo master bin/hello
	push_hook testrepo master config.env

	ssh_command "hookpull testrepo"
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

@test "Avoid 'login' fork bomb" {
	run ssh_command "login"
	[ $status -eq 1 ]
}
