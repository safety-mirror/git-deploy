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
	oldrev=${1-master}
	newrev=${2-master}
	dir=$3
	files_changed=$(git diff --name-only "$oldrev" "$newrev" 2>&1)

	# Enable debugging if requested
	if [ "$DEBUG" == "true" ]; then
		export CAPTURE_OUTPUT="false"
		env
		set -x
	fi

	# Environment sanity checking
	source ~/.profile
	set -o pipefail
	unset GIT_DIR
	if [ ! -z "$dir" ]; then
		cd "$dir"
	else
		cd ..
	fi
	env -i git reset --hard

	# Source config.env if present in old revision
	if git ls-tree --name-only -r "$oldrev" 2>&1 | grep -qFx config.env; then
		# shellcheck disable=SC1090
		source <(git cat-file blob "$oldrev:config.env")
	fi

	# If file outside of apps/ changed, such as config.env:
	if echo "$files_changed" | grep -qve '^apps/' >/dev/null; then

		# If ADMIN_USERS defined:
		# Only permit changes to files outside apps/ if author is in list
		if [[ ! -z ${ADMIN_USERS+x} ]]; then
			match="$CURRENT_USER| $CURRENT_USER|$CURRENT_USER "
			if [[ "$ADMIN_USERS" =~ $match ]]; then
				source <(git cat-file blob "$newrev:config.env")
			else
				echo "You must be listed in ADMIN_USERS to alter config.env"
				exit 1
			fi
		fi

		# If we made it this far, trust/source new revision of config.env
		source <(git cat-file blob "$newrev:config.env")
	fi

	get_hook_dir
}
