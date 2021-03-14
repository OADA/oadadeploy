# oadadeploy
----------------------------------
Command-line client to aid in managing an oada deployment.

This tool helps you to setup domains, add other services, and bring everything up and down together.
It primarily combines all your `docker-compose.yml` files together into a single master and enables
you write a single `docker-compose.override.yml`.  It also includes the proper environment and volume mounts
for your domains.

## Install
---------------------------------
Create a folder to hold your local `oada` installation, then curl this file into it and make it executable.

```bash
curl -OfsSL https://raw.githubusercontent.com/oada/oadadeploy/master/oadadeploy && chmod u+x oadadeploy
```

## Usage
----------------------------------
*Step 1*: Install oada and create deployment structure
```bash
oadadeploy init
source .oadadeploy/bash-completion
```
This creates the following structure:
```
oada/
     docker-compose.yml: oada release docker-compose file
domains/
     docker-compose.yml: all overrides necessary to enable your domains
     <domain_name>/: one folder per domain holding files like SSL certs, configs, private keys, etc.
services/
     docker-compose.yml: all your individual service's docker-compose.oada.yml files squashed together
     <service_name>/: one folder per installed service holding a file named "docker-compose.oada.yml"
support/: any files you need to map into your overrides specific to this deployment (signing keys, etc.)
docker-compose.yml: squashed together oada, domains, and services docker-compose.yml files.  This is your core deployment.
docker-compose.override.yml: anything you want to override from the docker-compose.yml file.
.oadadeploy/: place for oadaddeploy to keep track of things like which domain is your primary domain, bash-completion, etc.
```

*Step 2*: Setup your primary domain
If you are on a non-public IP, you need to setup localhost.  If you have a domain name, use that instead.
```
oadadeploy domain add -y localhost
```
This creates a `domains/localhost` file and refreshes your main docker-compose.yml.

*Step 3*: Install some services
If you have some properly-constructed services that you'd like to bring up and down with your
oada installation, or any modules that will override some oada behavior, you can
install them from a github release:
```
oadadeploy service install <org>/<repo>
```
The release you choose must have at least a docker-compose.oada.yml file for the service to be merged in.
The services are all merged into `services/docker-compose.yml` prior to merging into the main `docker-compose.yml`.

Note that you **can** just clone a git repo there instead of using oadadeploy to pull a release and it will work fine
as long as the thing you cloned has a docker-compose.oada.yml file.  If the service's directory has a `.git/` folder, 
it will not upgrade or mess with it.


## Additional Commands
-------------------------------
All commands will print usage information with `-h` or `help`.

**upgrade**: change your oada version to a different release.
```
oadadeploy upgrade
```

**refresh**: if you change anything in your base docker-compose files (oada/, domains/ services/), run this to re-merge them into `docker-compose.yml`.
```
oadadeploy refresh
```

**service upgrade**: upgrade a particular service to a new version
```
oadadeploy service upgrade <servicename>
```

**domain**: add a domain or refresh your domains/docker-compose.yml
```
oadadeploy domain add my.domain
oadadeploy domain refresh
```

## Create oadadeploy installable service
---------------------------------------

`oadadeploy` looks for `docker-compose.oada.yml` inside the `services/<name>` directory.  Simply create a service
with that file (which assumes the context is the root of an oadadeployment), and you're good.  If you want to
make your service installable and upgradeable, make the docker-compose.oada.yml file accessible in a github release.

