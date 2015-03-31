# Git-Deploy #

Git driven deployment strategy using git-hooks. Intended to bring version
control to common deployment tasks such as changing environment variables,
services, server provisioning, etc.

## Server Dependencies ##

  * Docker 1.5+
  * Systemd 218+

## Setup ##

1. Run git-deploy Docker image on CI server.

    ```bash
    cp git-deploy/sample.env git-deploy.env
    cp git-deploy/git-deploy.service .
    systemctl enable $PWD/git-deploy.service
    systemctl start git-deploy
    ```

3. Add any desired public keys

    ```bash
    docker exec -it git-deploy sh -c "curl https://github.com/someuser.keys >> .ssh/authorized_keys"
   ```

2. Setup Git-Deploy repo for each environment this deploy server can manage.

    ```bash
    docker exec -it git-deploy mkrepo staging
   ```

## Usage ##

1. Clone git-deploy repo for target env

    ```
    git clone git@ci.someserver.com:staging.git deploy
    ```

2. Set app environment vars, deployment details, and services

    ```
    cd deploy/apps/some-app
    vim some-app.env 
    vim some-app@.service
    vim some-app-helper@@.service
    vim some-app-helper.env 
    vim config.yml
    ```

3. Create shared environment vars (optional)

    ```
    vim deploy/global.env 
    ```

4. Adjust git-hooks (optional)

    ```
    vim deploy/hooks/post-receive
    ```

5. Deploy app

    ```
    git add .
    git commit -m 'Added some-app'
    git push staging master
    ```

    Changes are reflected in target Environment via defined git-hooks.
