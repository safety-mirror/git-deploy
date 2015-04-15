#!/bin/bash

# Very simple git-deploy test-suite.

# This script requires
# 1. The docker/aws-cli tools installed
# 2. AWS cli has write access to a bucket called 'git-deploy-test'

# Warning: This script modifies your known_hosts file and clears your bucket.
# Please inspect it carefully. 

GIT_DEPLOY_REPO=$PWD
TEST_REPOS=/tmp/git-deploy-test
PUBKEY_URL=https://github.com/lrvick.keys 
ENV_FILE=$PWD/test.env
GIT_SSH="/usr/bin/ssh -o StrictHostKeyChecking=no"

build_gd() {
    echo "Building Git-Deploy"
    cleanup
    docker build -t pebble/git-deploy .
}

restart_gd() {
    echo "Re-Starting Git-Deploy"
    cd $GIT_DEPLOY_REPO
    docker rm -f git-deploy
    docker run \
        -d \
        --name git-deploy \
        --env-file="$ENV_FILE" \
        -p 22:2222 \
        -e "DEBUG=true" \
        pebble/git-deploy
    sleep 10
    docker exec -it git-deploy sh -c "curl $PUBKEY_URL >> .ssh/authorized_keys"
}

cleanup() {
    aws s3 rm s3://git-deploy-test --recursive
    rm -rf $TEST_REPOS
    ssh-keygen -R localhost
}

mkrepo(){
    echo "Creating repo: $1"
    ssh -o StrictHostKeyChecking=no git@localhost mkrepo $1
}

clone(){
    echo "Cloning repo: $1"
    git clone git@localhost:${1}.git $TEST_REPOS/$1
}

test_commit() {
    echo "Making test commit to repo: $1"
    if [ -d "$TEST_REPOS/$1" ]; then
        cd $TEST_REPOS/$1
        date >> foo && git add . && git commit -m 'test' && git push origin master
    else
        echo "$TEST_REPOS/$1 does not exist"
        exit 1
    fi
}

build_gd
for REPO in repo1 repo2 repo3; do
    restart_gd
    mkrepo $REPO
    clone $REPO
    test_commit $REPO
    restart_gd
    test_commit $REPO
done
