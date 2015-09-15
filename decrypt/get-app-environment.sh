#!/bin/bash

# Import GPG keys
gpg2 --import keys/app-private.key 2>/dev/null
gpg2 --import keys/env-public.key 2>/dev/null

for KEY in $(etcdctl ls /env/${APP}/${ENVIRONMENT} | sort); do
	BASE_KEY=$(basename ${KEY})
	VALUE=$(etcdctl get ${KEY})

	# Attempt decryption
	DECRYPTED_VALUE=$(printf -- '-----BEGIN PGP MESSAGE-----\n\n%s\n-----END PGP MESSAGE-----\n' ${VALUE} | gpg2 --decrypt 2>/dev/null)
	if [ $? -eq 0 ]; then
		# This is a PGP block, is it for _this_ key?
		echo ${DECRYPTED_VALUE} | sed 's/ .*//g' | grep -qi ^KEY=${BASE_KEY}\$
		if [ "$?" -eq 0 ]; then
			# Valid ciphertext, emit decrypted value:
			DECRYPTED_VALUE=$(echo ${DECRYPTED_VALUE} | sed "s/^KEY=${BASE_KEY} //I")
		else
			# This is ciphertext stolen from another key
			DECRYPTED_VALUE=""
		fi
	else
		DECRYPTED_VALUE=""
	fi

	if [ -n "${DECRYPTED_VALUE}" ]; then
		echo ${BASE_KEY}=${DECRYPTED_VALUE}
	else
		echo ${BASE_KEY}=${VALUE}
	fi
done

