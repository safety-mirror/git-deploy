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

@test "Pre-Receive hook can reject bad commit" {
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

@test "Update hook can reject bad commit" {
    run_container
    ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo hooks/update
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
    run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Post-Commit hook can echo text" {
    run_container
    ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo hooks/post-commit
	run push_test_commit testrepo somefile
    echo "${lines[19]}" | grep "post-commit success"
}

@test "External pre-receive hook can reject bad commit" {
    run_container
	ssh_command "mkrepo hookrepo"
	ssh_command "mkrepo testrepo"
	clone_repo hookrepo
	clone_repo testrepo
    destroy_container
    run_container hookrepo
	push_hook hookrepo pre-receive
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
    run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}
