load test_helper

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
    run import_pubkeys
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
