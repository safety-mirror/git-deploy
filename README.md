# Git-Deploy #

Git driven deployment strategy using git-hooks. Intended to bring version
control to common deployment tasks such as changing environment variables,
services, server provisioning, etc.

## User Flow ##

1. Setup Git-Deploy repo for target env

    ```
    mkdir deploy
    cd deploy 
    git init
    git remote add staging git@staging.tunnels.someserver.com:staging.git
    git pull staging master
    ```

2. Add new app
   
    ```
    git clone https://github.com/pebble/git-deploy git-deploy
    mkdir -p deploy/apps/some-app
    cd deploy/apps/some-app
    cp ../../git-deploy/examples/example.env some-app.env 
    cp ../../git-deploy/examples/example@.service some-app@.service
    cp ../../git-deploy/examples/example-helper@.service some-app-helper@.service
    cp ../../git-deploy/examples/example-helper.env some-app-helper.env 
    cp ../../git-deploy/examples/config.yml config.yml
    ```

3. Change app environment vars, deployment details, and services as needed

    ```
    vim some-app.env 
    vim some-app@.service
    vim some-app-helper@@.service
    vim some-app-helper.env 
    vim config.yml
    ```

4. Create any shared environment vars as needed

    ```
    mkdir -p deploy/env
    cd deploy/env
    vim global.env 
    ```

5. Deploy app

    ```
    git add .
    git commit -m 'Added some-app'
    git push staging master
    ```

    Changes are reflected in target Environment via git-hooks.


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
