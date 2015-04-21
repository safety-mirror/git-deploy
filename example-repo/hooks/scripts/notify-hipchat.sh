#!/bin/bash

source hooks/config.env

API=https://api.hipchat.com/v2
AUTH_TOKEN=YOUR_TOKEN
ROOM_ID=32478

curl \
    -s \
    -S \
    -H 'Content-type: application/json' \
    -d@- \
    ${API}/room/${ROOM_ID}/notification\?auth_token\=${AUTH_TOKEN} <<EOF
    { "message": "git-deploy \n
VPC: ${VPC} \n
Environment: ${ENVIRONMENT} \n
Author: ${AUTHOR} \n
Message: ${MESSAGE} \n
Files Changed:\n
  ${FILES_CHANGED}"
    }
EOF
