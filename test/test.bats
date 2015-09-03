load test_helper

setup(){
    #build_container
	mkdir -p /tmp/git-deploy-test
	create_data_volume
}

teardown(){
	rm -rf /tmp/git-deploy-test
	destroy_data_volume
	destroy_container
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
	push_hook testrepo hooks/pre-receive
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

	push_hook testhookrepo pre-receive

	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]

    run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Internal update hook can reject bad commit" {
    run_container
    ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo hooks/update
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

	push_hook testhookrepo update

	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]

    run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Internal post-receive hook can echo text" {
    run_container
    ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo hooks/post-receive
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

	push_hook testhookrepo post-receive
    run push_test_commit testrepo somefile
    echo "${lines[6]}" | grep "post-receive success"
}
