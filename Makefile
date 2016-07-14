all:

clean:
	- docker rm -f gitdeploy_git-deploy_1
	docker-compose -f docker-compose.yml -f ./test/docker-compose.test.yml down --remove-orphans

build:
	docker-compose -f docker-compose.yml -f ./test/docker-compose.test.yml build


develop: clean build
	docker-compose -f docker-compose.yml -f ./test/docker-compose.test.yml up -d
	docker exec -it gitdeploy_test_1 bash

test: clean build
	docker-compose -f docker-compose.yml -f ./test/docker-compose.test.yml up -d
	docker exec -it gitdeploy_test_1 bats test.bats

.PHONY: all develop test
