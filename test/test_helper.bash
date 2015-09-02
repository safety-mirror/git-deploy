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
	docker build -t pebble/test-git-deploy .
}

run_container(){
	local hook_repo=${1-}
	docker run \
		-d \
		--name test-git-deploy \
		-e DEST=file:///backup_volume \
		-e PASSPHRASE=a_test_passphrase \
		-e HOOK_REPO=$hook_repo \
		--volumes-from test-git-deploy-data \
		-p 2222:2222 \
		-e "DEBUG=true" \
		pebble/test-git-deploy &> /dev/null
	sleep 5
}

destroy_container(){
	docker rm -f test-git-deploy &> /dev/null || return 0
}

gen_sshkey(){
	ssh-keygen -b 2048 -t rsa -f /tmp/git-deploy-test/sshkey -q -N ""
}

import_sshkey(){
	docker \
		exec \
		-i test-git-deploy \
		bash -c 'cat >> .ssh/authorized_keys' \
			< /tmp/git-deploy-test/sshkey.pub
}

git(){
	if [ ! -f /tmp/git-deploy-test/gitssh ]; then
		cat <<- "EOF" > /tmp/git-deploy-test/gitssh
			#!/bin/bash
			exec /usr/bin/ssh \
				-o UserKnownHostsFile=/dev/null \
				-o StrictHostKeyChecking=no \
				-i /tmp/git-deploy-test/sshkey $*
		EOF
		chmod +x /tmp/git-deploy-test/gitssh
	fi
	GIT_SSH="/tmp/git-deploy-test/gitssh" /usr/bin/git "$@"
}

clone_repo(){
	cd
	rm -rf /tmp/git-deploy-test/$1
	git clone ssh://git@localhost:2222/git/${1}.git /tmp/git-deploy-test/$1
}

ssh_command(){
	ssh \
		-p2222 \
		-i /tmp/git-deploy-test/sshkey \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		git@localhost \
		$1
}

push_test_commit() {
	local repo=${1-testrepo}
	local file_name=${2-test}
	if [ -d "/tmp/git-deploy-test/$1" ]; then
		cd /tmp/git-deploy-test/$1
		date >> $file_name
		git add .
		git commit -m "test commit"
		git push origin master
	else
		echo "/tmp/git-deploy-test/$1 does not exist"
		exit 1
	fi
}

push_hook() {
	local repo=${1-testrepo}
	local hook_name=${2-test}
	if [ -d "/tmp/git-deploy-test/$repo" ]; then
		cd /tmp/git-deploy-test/$repo
		mkdir -p hooks
		rm -rf hooks/*
		case $hook_name in
			pre-receive)
				cat <<- "EOF" > hooks/pre-receive
					#!/bin/bash

					# exit if we see 'badfile' in the list of files
					while read oldrev newrev refname; do
						for file in $(git diff --name-only $oldrev..$newrev); do
							[ $file != 'badfile' ] || exit 1
						done
					done
				EOF
				;;
			update)
				cat <<- "EOF" > hooks/update
					#!/bin/bash

					refname="$1"
					oldrev="$2"
					newrev="$3"

					# exit if we see 'badfile' in the list of files
					for file in $(git diff --name-only $oldrev..$newrev); do
						[ $file != 'badfile' ] || exit 1
					done
				EOF
				;;
			post-commit)
				cat <<- "EOF" > hooks/update
					#!/bin/bash

					echo post-commit success
				EOF
				;;
		esac
		git add .
		git commit -m "add $hook_name hook"
		git push origin master
	else
		echo "/tmp/git-deploy-test/$repo does not exist"
		exit 1
	fi
}
