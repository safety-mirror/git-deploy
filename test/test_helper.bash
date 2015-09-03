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
	gen_sshkey
	import_sshkey
}

destroy_container(){
	docker rm -f test-git-deploy &> /dev/null || return 0
}

gen_sshkey(){
	if [ ! -f /tmp/git-deploy-test/sshkey ]; then
		ssh-keygen -b 2048 -t rsa -f /tmp/git-deploy-test/sshkey -q -N ""
	fi
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
	oldpwd=$(pwd)
	cd
	rm -rf /tmp/git-deploy-test/$1
	git clone ssh://git@localhost:2222/git/${1} /tmp/git-deploy-test/$1
	cd $oldpwd
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
	local repo_folder="/tmp/git-deploy-test/$1"
	if [ -d "$repo_folder" ]; then
		date >> $repo_folder/$file_name
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder add .
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder commit -m "test commit"
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder push origin master
	else
		echo "/tmp/git-deploy-test/$1 does not exist"
		exit 1
	fi
}

push_hook() {
	local repo=${1-testrepo}
	local hook_file=${2-test}
	local hook_name=$(basename $hook_file)
	local hook_folder=$(dirname $hook_file)
	local repo_folder="/tmp/git-deploy-test/$repo/"
	if [ -d "$repo_folder" ]; then
		mkdir -p $repo_folder/$hook_folder
		cp $PWD/test/test-hooks/$hook_name $repo_folder/$hook_file
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder add .
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder commit -m "add $hook_name hook"
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder push origin master
	else
		echo "/tmp/git-deploy-test/$repo does not exist"
		exit 1
	fi
}
