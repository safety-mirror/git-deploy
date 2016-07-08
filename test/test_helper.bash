destroy_backups(){
    docker exec -it "gitdeploy_git-deploy_1" \
		bash -c "rm -rf /backup_volume/*" &> /dev/null
}

reset_container(){
	local hook_repo=${1-}
	local hook_repo_keys=${2}
	if [ -z "$hook_repo_keys" ]; then
		HOOK_REPO_VERIFY=false
	else
		HOOK_REPO_VERIFY=true
	fi
	docker rm -f gitdeploy_git-deploy_1
	docker run \
		-d \
 		--net gitdeploy_default \
		-e DEST=file:///backup_volume \
		-e PASSPHRASE=a_test_passphrase \
		-e HOOK_REPO=$hook_repo \
		-e HOOK_REPO_VERIFY=$HOOK_REPO_VERIFY \
		-e DEPLOY_TIMEOUT_TERM=10s \
		-e DEPLOY_TIMEOUT_KILL=12s \
		--volumes-from gitdeploy_git-deploy-data_1 \
		-v /dev/urandom:/dev/random \
		-p 2222:2222 \
		--name gitdeploy_git-deploy_1 \
		gitdeploy_git-deploy
		#pebble/gitdeploy_git-deploy_1 &> /dev/null
	sleep 5
	import_sshkey
	for key_id in $hook_repo_keys; do
		import_gpgkey $key_id
	done	
}

make_hook_repo(){
	local hook_repo=${1-testhookrepo}
	docker exec gitdeploy_git-deploy_1 bash -c "git init --bare $hook_repo"
}

import_sshkey(){
	docker \
		exec \
		-i gitdeploy_git-deploy_1 \
		bash -c 'cat >> .ssh/authorized_keys' \
			< test-keys/test-sshkey.pub
}

import_gpgkey(){
	local key_id=${1-}
	docker \
		exec \
		-i gitdeploy_git-deploy_1 \
		bash -c 'cat | gpg --import' \
			< ${PWD}/test-keys/${key_id}.key
	docker \
		exec \
		-i gitdeploy_git-deploy_1 \
		bash -c 'cat >> /tmp/trustfile; gpg --import-ownertrust /tmp/trustfile' \
			< ${PWD}/test-keys/${key_id}.key.trust
}

container_command(){
	docker \
		exec \
		-i gitdeploy_git-deploy_1 \
		$* <&0
}

git(){
	if [ ! -f /tmp/git-deploy-test/gitssh ]; then
		cat <<- "EOF" > /tmp/git-deploy-test/gitssh
			#!/bin/bash
			exec /usr/bin/ssh \
				-o UserKnownHostsFile=/dev/null \
				-o StrictHostKeyChecking=no \
				-i /test/test-keys/test-sshkey $*
		EOF
		chmod +x /tmp/git-deploy-test/gitssh
	fi
	GIT_SSH="/tmp/git-deploy-test/gitssh" /usr/bin/git "$@"
}

clone_repo(){
	oldpwd=$(pwd)
	cd
	rm -rf /tmp/git-deploy-test/$1
	git clone ssh://git@git-deploy:2222/git/${1} /tmp/git-deploy-test/$1
	cd $oldpwd
}

ssh_command(){
	ssh \
		-p 2222 \
		-a \
		-i /test/test-keys/test-sshkey \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		git@git-deploy \
		$1
}

set_config() {
	local repo=${1-testrepo}
	local key=${2-foo}
	local value=${3-bar}
	local repo_folder="/tmp/git-deploy-test/$1"
	if [ -d "$repo_folder" ]; then
		echo "export $key=$value" >> $repo_folder/config.env
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder add .
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder commit -m "test commit"
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder push origin master
	else
		echo "/tmp/git-deploy-test/$1 does not exist"
		exit 1
	fi
}

push_test_commit() {
	local repo=${1-testrepo}
	local file_name=${2-test}
	local repo_folder="/tmp/git-deploy-test/$1"
	if [ -d "$repo_folder" ]; then
		file_dir=$(dirname ${file_name})
		if [ "${file_dir}" != "." ]; then
			mkdir -p ${repo_folder}/${file_dir}
		fi
		date >> ${repo_folder}/${file_name}
		git --git-dir=${repo_folder}/.git --work-tree=${repo_folder} add .
		git --git-dir=${repo_folder}/.git --work-tree=${repo_folder} commit -m "test commit"
		git --git-dir=${repo_folder}/.git --work-tree=${repo_folder} push origin master
	else
		echo "/tmp/git-deploy-test/$1 does not exist"
		exit 1
	fi
}

push_hook() {
	local repo=${1-testrepo}
	local branch=${2-master}
	local hook_file=${3-test}
	local sign_key=${4}
	local hook_name=$(basename $hook_file)
	local hook_folder=$(dirname $hook_file)
	local repo_folder="/tmp/git-deploy-test/$repo/"
	if [ -d "$repo_folder" ]; then
		mkdir -p $repo_folder/$hook_folder
		hook_source=$PWD/test-hooks/$hook_file
		if [ -f $PWD/test-hooks/$hook_name ]; then
			hook_source=$PWD/test-hooks/$hook_name
		fi

		cp $hook_source $repo_folder/$hook_file
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder checkout -B $branch
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder add .
		if [[ ! -z "$sign_key" ]]; then
			export GNUPGHOME="/tmp/git-deploy-test/gpg"
			rm -rf $GNUPGHOME
			mkdir -p $GNUPGHOME
			echo gpg --import test-keys/${sign_key}.key
			gpg --import test-keys/${sign_key}.key
			git \
				--git-dir=${repo_folder}/.git \
				--work-tree=${repo_folder} \
					commit \
						-m "add $hook_name hook" \
						--gpg-sign=${sign_key}
			unset GNUPGHOME
		else
			git --git-dir=$repo_folder/.git --work-tree=$repo_folder commit -m "add $hook_name hook"
		fi
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder push origin $branch
	else
		echo "/tmp/git-deploy-test/$repo does not exist"
		exit 1
	fi
}
