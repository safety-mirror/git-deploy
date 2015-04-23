export GIT_SSH_COMMAND=" ssh \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no"

destroy_data_volume(){
    docker rm -f test-git-deploy-data  &> /dev/null || return 0
}

create_data_volume(){
    docker run \
        -v /backup_volume \
        --name test-git-deploy-data \
        pebble/git-deploy \
        true &> /dev/null
}

build_container(){
    docker build -t pebble/git-deploy .
}

run_container(){
    docker run \
        -d \
        --name test-git-deploy \
        -e DEST=file:///backup_volume \
        -e PASSPHRASE=a_test_passphrase \
        --volumes-from test-git-deploy-data \
        -p 2222:2222 \
        -e "DEBUG=true" \
        pebble/git-deploy &> /dev/null
    sleep 5
}

destroy_container(){
    docker rm -f test-git-deploy &> /dev/null || return 0
}

import_pubkeys(){
    for KEY in ~/.ssh/*.pub; do
        docker exec -i test-git-deploy \
            bash -c 'cat >> .ssh/authorized_keys' < $KEY
    done
}


clone_repo(){
    rm -rf /tmp/git-deploy-test/$1
    git clone ssh://git@localhost:2222/git/${1}.git /tmp/git-deploy-test/$1
}

ssh_command(){
    ssh \
        -p2222 \
        -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no \
        git@localhost \
        $1
}

push_test_commit() {
    if [ -d "/tmp/git-deploy-test/$1" ]; then
        cd /tmp/git-deploy-test/$1
        date >> foo && git add . && git commit -m 'test' && git push origin master
    else
        echo "/tmp/git-deploy-test/$1 does not exist"
        exit 1
    fi
}
