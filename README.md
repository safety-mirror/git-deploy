# Git-Deploy #

Git driven deployment strategy using git-hooks. Intended to bring version
control to common deployment tasks such as changing environment variables,
services, server provisioning, etc.

## Server Dependencies ##

  * Docker 1.5+
  * Systemd 218+

## Setup ##

1. Configure environment file

    ```bash
    cp git-deploy/sample.env git-deploy.env
    vim git-deploy.env
    ```

    Option legend:

    Key                   | Usage
    --------------------- | ---------------------------------------------------
    DEST                  | Duplicity backup destination. See [Duplicity Docs](http://linux.die.net/man/1/duplicity)
    PASSPHRASE            | Used to symmetrically decrypt/encrypt backups via GPG
    HOOK_REPO             | External Git repository where hooks will be sourced from. If undefined hooks will be sourced from 'hooks' folder in each repo
    HOOK_REPO_VERIFY      | If 'true' hook_repo must be signed by key trusted in local gpg keyring
    AWS_ACCESS_KEY_ID     | Required if using AWS S3 as DEST
    AWS_SECRET_ACCESS_KEY | ^

2. Run git-deploy Docker image on CI server.

    ```bash
    cp git-deploy/git-deploy.service .
    systemctl enable $PWD/git-deploy.service
    systemctl start git-deploy
    ```

3. Add any desired public keys

  SSH:
    ```bash
    docker exec -it git-deploy sh -c "curl https://github.com/someuser.keys >> .ssh/authorized_keys"
    ```

  GPG:
    ```bash
    docker exec -it git-deploy bash
    gpg --recv-keys E90A401336C8AAA9
    gpg --edit-key E90A401336C8AAA9
    gpg> trust
    gpg> save
    ```

4. Setup Git-Deploy repo for each environment this deploy server can manage.

    ```bash
    ssh git@ci.someserver.com mkrepo staging.git
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

## Reading ssh logs ##

It is possible to read SSH logs by overwriting a specific log path (e.g. `/var/log/secure`)
with your instance host's file. You can adjust the `git-deploy.service` like:

```bash
ExecStart=/usr/bin/docker run \
  -p 22:2222 \
  --env-file="/home/core/git-deploy.env"
  -e SSH_LOG_FILE=/var/log/secure \
  -v /var/log/secure:/var/log/secure \
  -v /etc/hosts.deny:/etc/hosts.deny \
  --name="git-deploy" \
  pebble/git-deploy
```

This allows you to read and act on logs written to this file, for example using
DenyHosts to read the logs, and writing to `hosts.deny` to deny certain hosts.

## Debugging ##

If you need to manually debug/edit the hooks of a repo after creation, you can
mount the running /git volume within a debug environment such as a debian
container like so:

```bash
docker run -ti --volumes-from=git-deploy debian bash
vim /git/somerepo.git/.git/hooks/post-receive
```

## Testing ##

To run tests you will need:
  * [bats](https://github.com/sstephenson/bats) installed
  * port 2222 open
  * working ssh public keys in your ~/.ssh folder

Run tests:
```
bats test/test.bats
```
