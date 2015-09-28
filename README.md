# Git-Deploy #

Git driven deployment strategy using git-hooks. Intended to bring version
control to common deployment tasks such as changing environment variables,
services, server provisioning, etc.

## Philosophy

TL;DR: Version Controlled Immutable Deployment

Everything should be a commit. Deploying new cloud instances? That's a commit.
DNS change? That is a commit too. Rotating database passwords? Also a commit.
Everything about an application, all the way through the stack, should be
version controlled, and able to be audited and rolled back at any time.

Services like Heroku and Github have been using Git hooks to predictably manage
deployments with success for many years. This strategy works, and the goal of
git-deploy is to provide a light framework for implementing flows like this in
your own organization, with hooks tailored to your specific needs. It also
allows you to keep secrets and deployment specific information out of your
primary app repos, and in an encrypted cloud-archived repo behind your
firewall. All actions flowing through central environment specific repos and
hooks leaves all the wires exposed under the hood so sysadmins/devops can
intervene or assist with customized solutions as needed.

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
    ssh git@ci.someserver.com mkrepo staging
   ```

## Examples

These examples make a lot of assumptions about your environment, and are
intended to show how git-deploy could be used in develop and staging/production
modes respectively, and what it could cover provided appropriate hooks.

These examples assume a helper-service exists in your infra to automatically
make templated commits on behalf of developers for the develop environment.

The helper service and hooks are outside the scope of git-deploy itself, as 
git-deploy aims to make as few assumptions about your environment as possible.
We encourage the community to contribute their own solutions for these items.
Deployment actions could be handled within git-deploy-hooks by common CI tools
such as Ansible, Puppet, or Chef. A series of shell scripts could cover the
same.

### Example Develop Environment Usage ##

#### Deploying app ####

1. Developer merges to ```develop``` branch at ```github.com:some-app.git```

2. Github notifies a deploy-helper service running in ```develop``` environment

3. Deploy helper service commits templated change to ```
git@ci.someserver.com:develop.git```

4. Git-deploy hooks build and deploy 'develop' branch of
```github.com:some-app.git``` to ``develop.some-app.example.com```

5. Git-deploy hooks send email/chat notifications to contirbuttors to notify
them deployment is complete

#### Customizing deployment ####

Sometimes one-size-fits-all templates may not meet a certian use case.
Perhaps a developer wants a database such as Redis to use alongside their app
container in the develop environment. They also need default environment
variables overridden to point to this redis database.

Depending on level of experience either the developer, or someone
assisting from a devops team could do the following:

1. Clone develop git-deploy repo

    ```
    git clone git@ci.someserver.com:develop.git
    cd develop
    ```

2. Copy a unit file template for a development redis container to app

    ```
    cp templates/redis@.service apps/some-app/some-app-redis@.service
    
    ```

3. Update app environment variable to point to local DNS for Redis db container

    ```
    echo "REDIS_HOST=some-app-redis:6379" >> apps/some-app/some-app.env
    ```

4. Deploy change

    ```
    git add .
    git commit -m 'Added and linked redis container to some-app'
    git push
    ```

    Changes are reflected in target Environment via defined git-hooks.


### Example Staging/Production Environment Usage ##

1. Clone git-deploy repo for target env

    ```
    git clone git@ci.someserver.com:staging.git deploy
    ```

2. Set app environment vars, deployment details, and services

    ```
    cd deploy/apps/some-app
    vim some-app@.service
    vim some-app.env 
    vim some-app-helper@.service
    vim some-app-helper.env 
    vim some-app-deploy.env
    ```

3. Create shared environment vars (optional)

    ```
    vim deploy/config.env
    ```

4. Adjust git-hooks (optional)

    ```
    vim deploy/hooks/pre-receive
    ```

5. Deploy app

    ```
    git add .
    git commit -m 'Added some-app'
    git push
    ```

    Changes are reflected in target Environment via defined git-hooks.

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
