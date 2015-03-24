# Git-Deploy #

Git driven deployment strategy using git-hooks. Intended to bring version
control to common deployment tasks such as changing environment variables,
services, server provisioning, etc.

## User Flow ##

1. Setup Git-Deploy repo for target env

    ```
    mkdir git-deploy
    git init
    git remote add staging git@staging.tunnels.someserver.com:staging.git
    git pull staging master
    ```

2. Add new service
   
    ```
    git clone https://github.com/pebble/git-deploy git-deploy
    mkdir some-service
    cd some-service
    cp ../git-deploy/examples/example.env some-service.env 
    cp ../git-deploy/examples/example@.system some-service@.system
    cp ../git-deploy/examples/example-helper@.system some-service-helper@.system
    cp ../git-deploy/examples/example-helper.env some-service-helper.env 
    cp ../git-deploy/examples/Deploy Deploy
    ```

3. Change Environment vars, deployment details, and services as needed

    ```
    vim some-service.env 
    vim some-service@.system
    vim some-service-helper@@.system
    vim Deploy
    ```

4. Deploy service

    ```
    git add .
    git commit -m 'Changed var foo on some-service'
    git push staging master
    ```

    Changes are reflected in target Environment via git-hooks. The End.


## Server Setup ##

1. Setup Git on deploy server in target environment.

    ```bash
    useradd -m -d /home/core/deploy/ -s /usr/bin/git-shell
    ```

2. Setup Git-Deploy repo for each environment this deploy server can manage.

    ```bash
    mkdir -p /home/core/deploy/staging.git 
    cd /home/core/deploy/staging.git
    git init --bare
    rm hooks
    git clone https://github.com/pebble/git-deploy hooks
    ```

3. Create hook configuration for each repo to suit your deployment needs

    ```bash
    cp /home/core/deploy/staging.git/hooks/config.yml{.sample,}
    vim /home/core/deploy/staging.git/hooks/config.yml
    ```
