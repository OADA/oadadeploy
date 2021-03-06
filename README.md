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
curl -ofsSL https://raw.githubusercontent.com/oada/oadadeploy/master/oadadeploy && chmod u+x oadadeploy
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
services/
docker-compose.yml
docker-compose.override.yml
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


## Additional Commands
-------------------------------
All commands will print usage information with `-h` or `help`.

*upgrade*: change your oada version to a different release.
```
oadadeploy upgrade
```

*service upgrade*: upgrade a particular service to a new version
```
oadadeploy service upgrade <servicename>
```

*domain*: add a domain or refresh your domains/docker-compose.yml
```
oadadeploy domain add my.domain
oadadeploy domain refresh
```


