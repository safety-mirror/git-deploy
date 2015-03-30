#!/bin/bash

REPO_NAME=$1

if [ -z "$1" ]; then
  echo "usage: mkrepo repo-name"
  exit 1
fi

mkdir -p /git/${REPO_NAME}.git
cd /git/${REPO_NAME}.git
git init
git config --bool receive.denyCurrentBranch false

cat <<- EOF > .git/hooks/post-receive
  cd ..
  env -i git reset --hard
  bash ./hooks/post-receive
EOF
chmod +x .git/hooks/post-receive

ln -s -f ../../hooks/post-merge .git/hooks/post-merge

cd /git