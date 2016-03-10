ifeq (, $(shell which docker-machine))
	ENV_VARS=DOCKER_HOST_IP="localhost"
else
	ENV_VARS=DOCKER_HOST_IP=$(shell docker-machine ip `docker-machine active`)
endif

all:

test:
	docker build -t pebble/test-git-deploy .
	@ $(ENV_VARS) bats test/test.bats

.PHONY: all test
