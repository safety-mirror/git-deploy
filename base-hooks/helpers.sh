#!/bin/bash

get_hook_dir(){

	if [ ! -z "$HOOK_REPO" ]; then
		if [ ! -z "$ENVIRONMENT" ]; then
			hook_dir="/git/${ENVIRONMENT}_hooks"
		else
			hook_dir="/git/hooks"
		fi
		if [ ! -d "$hook_dir" ]; then
			mkdir -p "$hook_dir"
			git clone "$HOOK_REPO" "$hook_dir" >/dev/null 2>&1
		fi
		git \
			--git-dir="$hook_dir/.git" \
			--work-tree="$hook_dir" \
			fetch --all >/dev/null 2>&1
		if [ ! -z "$HOOK_REPO_REF" ]; then
			git \
				--git-dir="$hook_dir/.git" \
				--work-tree="$hook_dir" \
				reset --hard "origin/$HOOK_REPO_REF" >/dev/null 2>&1
		else
			git \
				--git-dir="$hook_dir/.git" \
				--work-tree="$hook_dir" \
				pull >/dev/null 2>&1
		fi
		if [ "$HOOK_REPO_VERIFY" = true ]; then
			sign_status=$( git --git-dir="$hook_dir/.git" --work-tree="$hook_dir" log --show-signature --pretty="%G?" -1 HEAD | tail -n1 )
			if [ "$sign_status" != "G" ]; then
				echo "Latest commit in $HOOK_REPO is not signed by a known key"
				exit 1
			fi
		fi
	else
		hook_dir='hooks'
	fi
	export HOOK_DIR=$hook_dir
}

setup_env(){
	ref=${1-master}
	dir=$2
	source ~/.profile
	set -o pipefail
	unset GIT_DIR
	if [ ! -z "$env" ]; then
		cd "$dir"
	else
		cd ..
	fi
	env -i git reset --hard
	if git ls-tree --name-only -r "$ref" 2>&1 | grep -qFx config.env; then
		# shellcheck disable=SC1090
		source <(git cat-file blob "$ref:config.env")
	fi
	get_hook_dir
}
