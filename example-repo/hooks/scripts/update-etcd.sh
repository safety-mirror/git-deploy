#!/bin/bash

source hooks/config.env

ENV_FILES=$(printf %s "${FILES_CHANGED}" | grep "^apps\/.*\.env$")

for ENV_FILE in $ENV_FILES; do
  KEY=/env/$(echo $ENV_FILE | sed 's/.*\/\(.*\)\.env/\1/g' )/$ENVIRONMENT
  for LINE in $(cat $ENV_FILE); do
    etcdctl set ${KEY}/$(echo $LINE | sed 's/=.*/ /g') "$(echo $LINE | sed 's/^[^=]\+=//g' )"
  done
done
