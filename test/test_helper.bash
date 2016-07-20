setup(){
	rm -rf /tmp/git-deploy-test
	mkdir -p /tmp/git-deploy-test
	reset_container
	destroy_backups
	set_container "git-deploy-test"
}

teardown(){
	rm -rf /tmp/git-deploy-test
}

destroy_backups(){
	for suffix in test test-exthooks test-exthooks-sig; do
		docker exec -i "git-deploy-$suffix" \
			sh -c "rm -rf /backup_volume/*"
	done
}

reset_container(){
	for suffix in test test-exthooks test-exthooks-sig; do
		docker exec --user root -i git-deploy-$suffix sh -c "rm -rf /git && cp -R /git-initial /git && chown -R git: /git && chmod -R 777 /backup_volume"
		import_sshkey "git-deploy-$suffix"
	done
	import_gpgkey "94F94EC1" "git-deploy-test-exthooks-sig"
}

make_hook_repo(){
	local hook_repo=${1-testhookrepo}
	docker exec git-deploy-test bash -c "git init --bare $hook_repo"
}

import_sshkey(){
	local CONTAINER=${1-"git-deploy-test"}
	container_command "ssh-key testuser $(cat test-keys/test-sshkey.pub)"
	docker \
		exec \
		-i $CONTAINER \
		bash -c 'cat >> /git/.ssh/id_rsa; chmod 400 /git/.ssh/id_rsa' \
			< ${PWD}/test-keys/test-sshkey
	docker \
		exec \
		-i $CONTAINER \
		bash -c 'cat >> /git/.ssh/config' \
			< ${PWD}/ssh_client.config
}

import_gpgkey(){
	local key_id=${1-}
	local CONTAINER=${2-"git-deploy-test"}
	docker \
		exec \
		-i $CONTAINER \
		bash -c 'cat | gpg --import' \
			< ${PWD}/test-keys/${key_id}.key
	docker \
		exec \
		-i $CONTAINER \
		bash -c 'cat >> /tmp/trustfile; gpg --import-ownertrust /tmp/trustfile' \
			< ${PWD}/test-keys/${key_id}.key.trust
}

container_command(){
	docker \
		exec \
		-i $CONTAINER \
		$* <&0
}

set_container(){
	export CONTAINER=${1-"git-deploy-test"}
}

clone_repo(){
	local repo=${1-"test-repo"}
	local CONTAINER=${2-"$CONTAINER"}
	oldpwd=$(pwd)
	cd
	rm -rf /tmp/git-deploy-test/$1
	git clone ssh://git@${CONTAINER}:2222/git/${1} /tmp/git-deploy-test/$1
	cd $oldpwd
}

ssh_command(){
	key=${2-"test-keys/test-sshkey"}
	ssh \
		-p 2222 \
		-a \
		-i $key \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		git@${CONTAINER} \
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
