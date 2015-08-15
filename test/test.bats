load test_helper

@test "Prepare environment" {
	run prepare_environment
	[ "$status" -eq 0 ]
}

@test "Build container" {
	run build_container
	[ "$status" -eq 0 ]
}

@test "Create data volume" {
	destroy_container
	destroy_data_volume
	create_data_volume
}

@test "Run container" {
	run run_container
	[ "$status" -eq 0 ]
}

@test "Import ssh keys into container" {
	run import_sshkey
	[ "$status" -eq 0 ]
}

@test "Run backup" {
	run ssh_command "backup"
	[ "$status" -eq 0 ]
}

@test "Create a new repository" {
	run ssh_command "mkrepo testrepo"
	[ "$status" -eq 0 ]
}

@test "Destroy Container" {
	run destroy_container
	[ "$status" -eq 0 ]
}

@test "Restore Backup" {
	run run_container
	[ "$status" -eq 0 ]
}

@test "Clone repository" {
	run clone_repo testrepo
	[ "$status" -eq 0 ]
}

@test "Push commit to repository" {
	run push_test_commit testrepo
	[ "$status" -eq 0 ]
}

@test "Add pre-commit hook" {
	run push_hook testrepo pre-receive
	[ "$status" -eq 0 ]
}

@test "Pre-Commit hook can allow file" {
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
}

@test "Pre-Commit hook can reject file" {
	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Add update hook" {
	run push_hook testrepo update
	[ "$status" -eq 0 ]
}

@test "Update hook can allow file" {
	run push_test_commit testrepo goodfile
	[ "$status" -eq 0 ]
}

@test "Update hook can reject file" {
	run push_test_commit testrepo badfile
	[ "$status" -eq 1 ]
}

@test "Add post-commit hook" {
	run push_hook testrepo post-commit
	[ "$status" -eq 0 ]
}

@test "Post-Commit hook can echo text" {
	run push_test_commit testrepo somefile
	echo "${lines[19]}" | grep "post-commit success"
}
