ifeq (, $(shell which docker-machine))
	export DOCKER_HOST_IP="localhost"
else
	export DOCKER_HOST_IP=$(shell docker-machine ip `docker-machine active`)
endif

all:

test:
	docker build -t pebble/test-git-deploy .
	@bats test/test.bats

.PHONY: all test
