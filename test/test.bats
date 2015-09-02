load test_helper

setup(){
    #build_container
	mkdir -p /tmp/git-deploy-test
	create_data_volume
	run_container
    gen_sshkey
	import_sshkey
}

teardown(){
	rm -rf /tmp/git-deploy-test
	destroy_container
	destroy_data_volume
}

@test "Can backup and restore a repository" {
	ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_test_commit testrepo
	destroy_container
	run_container
	run clone_repo testrepo
	[ "$status" -eq 0 ]
}

@test "Pre-Commit hook can reject bad commit" {
    ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo pre-receive
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
    run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Update hook can reject bad commit" {
    ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo update
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
    run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Post-Commit hook can echo text" {
    ssh_command "mkrepo testrepo"
	clone_repo testrepo
	push_hook testrepo post-commit
	run push_test_commit testrepo somefile
    echo "${lines[5]}" | grep "post-commit success"
}
