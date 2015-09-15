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
	[ "$status" -eq 1 ]

	# accepted after pre-receive completes
	sleep 5
	run push_test_commit testrepo slowfile
	[ "$status" -eq 0 ]
}

@test "Generate application secret" {
	run_container
	push_test_app testrepo testapp

	run ssh_command "secret testrepo testapp foo bar"
	[ "$status" -eq 0 ]
}

@test "Generate application secret from stdin" {
	run_container
	push_test_app testrepo testapp

	date | ssh_command "secret testrepo testapp foo"
	[ "$?" -eq 0 ]
}

@test "Generate application secret - missing arguments" {
	run_container
	push_test_app testrepo testapp

	run ssh_command "secret"
	[ "$status" -ne 0 ]
	run ssh_command "secret testrepo"
	[ "$status" -ne 0 ]
	run ssh_command "secret testrepo testapp"
	[ "$status" -ne 0 ]
}

@test "Generate application secret - invalid environment" {
	run_container

	run ssh_command "secret testrepo testapp foo bar"
	[ "$status" -ne 0 ]
}

@test "Generate application secret - invalid application" {
	run_container
	ssh_command "mkrepo testrepo"

	run ssh_command "secret testrepo testapp foo bar"
	[ "$status" -ne 0 ]
}

@test "Generate application secret multiple environments" {
	run_container
	push_test_app testrepo testapp
	push_test_app otherrepo testapp

	run ssh_command "secret testrepo testapp foo bar"
	[ "$status" -eq 0 ]
	run ssh_command "secret otherrepo testapp foo bar"
	[ "$status" -eq 0 ]
}

@test "Roundtrip application secret" {
	run_container
	push_test_app testrepo testapp
	run ssh_command "secret testrepo testapp foo bar"

	start_etcd

	# Store secret: foo=bar
	echo ${lines[1]} | docker exec -i test-git-deploy-etcd etcdctl set /env/testapp/testrepo/FOO >/dev/null
	# Store plaintext: foz=BaZ
	docker exec -i test-git-deploy-etcd etcdctl set /env/testapp/testrepo/FOZ BaZ >/dev/null

	extract_pgp_keys
	build_decrypt_container
	run docker run --rm \
		--link test-git-deploy-etcd \
		-e ENVIRONMENT=testrepo \
		-e APP=testapp \
		-e ETCDCTL_PEERS=http://test-git-deploy-etcd:4001 \
		-v /tmp/git-deploy-test/keys/:/home/decrypt/keys/:ro \
		-t test-git-deploy-decrypt

	# Verify environment
	echo ${lines[0]} | grep FOO=bar
	echo ${lines[1]} | grep FOZ=BaZ
}
