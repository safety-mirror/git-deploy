ENV_VARS=DOCKER_HOST_IP=localhost


all:

test:
	docker build -t pebble/test-git-deploy .
	@ $(ENV_VARS) bats test/test.bats

.PHONY: all test clean
