Educational repository demonstrating approaches for using `ansible-container` to build custom dockerized applications.

## Challenges to address

In a typical site scenario, we should be able

- setup necessary development environment for ansible-container
- build custom application image using ansible-container
- run application , optionally debug application, stop application


Ideally, everything seems nice per demo found at  https://github.com/ansible/ansible-container-demo

but let's check if we would be able to do the same with our custom application supposed to be running on alpine based image. 


## Necessary setup for building image using ansible container

As tool is under active development it makes sense to use python environment to isolate the image building environment.

```shell
# optional create dedicated python virtual environment
mkvirtualenv ansible-container
# and/or activate it
workon ansible-container
```

Install building dependencies
```shell
pip install -U pip
pip install ansible
pip install ansible-container
pip install prudentia
```

at the moment of article writing versions used are

```shell
ansible==2.3.2.0
ansible-container==0.9.1
prudentia==2.4
```

you are invited to use pip freeze into requirements.txt for your release builds, to ensure that versions used are the same between distance builds.

Optionally you may put `ansible.cfg` file to configure your project specific settings, like role search path.

`ansible.cfg` :
```
# Set any ansible.cfg overrides in this file.
# See: https://docs.ansible.com/ansible/intro_configuration.html#explanation-of-values-by-section

```

## Prepare ansible roles you want to use with image

Assuming, you want to build custom php based image for your application. If you already used ansible before, there are big chances, that you already have standalone ansible roles, parts or fragments.

In our case we will use `sa-php-container` ansible role https://github.com/softasap/sa-php-container based historically on `sa-lamp`  https://github.com/softasap/sa-lamp.

In particular, this ansible role allows us to:
- have composer enabled image (by specifiing `option_install_composer: true`)
- in order to have ability to build "staging troubleshoot image" - possibility to have preconfigured xdebug up

```
option_install_xdebug: true
xdebug_version: 2.5.0
xdebug_remote_port: 9004 # set to 9000, if port is not exposed over the same box
option_allow_xdebug_workarounds: true
```
- specify image timezone
```
timezone: "Europe/Kiev"
```
- specify php extensions needed for your application
```

php_extensions:
  # - "bcmath" # ok
  # - "bz2"    # ok
  # - "ctype"  # ok
   - "curl"   # ok
  # - "dom"    # ok
  # - "gd"     # ok
  # - "gettext" #ok
  # - "gmp"    # ok, but NO AUTO DEPENDENCIES for official base image
  # - "iconv"  # ok
   - "json"   # ok
  # - "mcrypt" # ok
  # - "memcache" # ok, but NO AUTO DEPENDENCIES for official base image
  # - "mssql"    # ok, but NO AUTO DEPENDENCIES for official base image
  # - "mysql"  # ok
  # - "odbc"   # ok, but NO AUTO DEPENDENCIES for official base image
  # - "openssl" # ok, but NO AUTO DEPENDENCIES for official base image
  # - "pdo"    #ok
  # - "pdo_dblib" # ok, but NO AUTO DEPENDENCIES for official base image
  # - "pdo_mysql" # ok
  # - "pdo_odbc" # ok, but NO AUTO DEPENDENCIES for official base image
  # - "pdo_pgsql" # ok
  # - "pdo_sqlite" # ok
   - "phar"   # ok
  # - "soap"   # ok
  # - "sqlite3" # ok, but NO AUTO DEPENDENCIES for official base image
  # - "xcache" # ok, but NO AUTO DEPENDENCIES for official base image
  # - "xmlreader" # ok
  # - "xmlrpc" # ok
  # - "xsl"    # ok
  # - "zip" # ok, but NO AUTO DEPENDENCIES for official base image
  ```

  - specify pecl extensions needed
```YAML
  pecl_extensions: []
```
  - specify development extensions, if any
```YAML
php_dev_extensions:
   - xdebug
```  

Assume we have all 3rd party roles used under the `roles/` , in that way no additional changes needed to be introduced in `ansible.cfg`

## Configure container.yml for ansible-container enabled project

Time to create `container.yml`. This is main orchestration document for Ansible Container. Good news: it’s much like a docker-compose.yml file, defining the services that make up the application, the relationships between each, and how they can be accessed from the outside world.

More over: the structure and contents of the file are based on Docker Compose, supporting versions 1 and 2. Looking at a container.yml file you will recognize it as mostly Compose with a few notable exceptions. There are directives that are not supported, because they do not translate to the supported clouds, and there are new directives added to support multi-environment, and multi-cloud configurations.

The goal for container.yml is to provide a single definition of the application that defines how to build images (minimum), and even how to run in development, and how to deploy to a production cloud environment. Ideally, you would use the same container.yml definition that works throughout the application lifecycle.

Let's take a look on a sample container.yml

Important setting is: `conductor_base` - this is special building environment capable to run ansible, which is linked during the build stage. It should always be based on the same distributive as your ansible-container project. For example, below we are building our php container basing on alpine 3.5 , and thus our conductor image also is based on alpine 3.5. If your application is based on debian, than conductor image also should be from the same family.

Case when you want to use ansible-container with multiple base images for now is not covered, perhaps you would need to separate builds.

As you see, syntax is very close do docker compose. More settings available can be discovered at https://docs.ansible.com/ansible-container/container_yml/reference.html

```yaml
version: "2"
settings:
  conductor_base: alpine:3.5
  # conductor_base: debian:jessie

services:
   nginx:
      from: nginx:alpine
      container_name: php-otp-microservice-nginx
      ports:
        - "8080:80"
      volumes:
        - "$PWD/app/nginx/site.conf:/etc/nginx/conf.d/default.conf"
      volumes_from:
        - php
   php:
     # from: php:5.6.30-fpm
     from: alpine:3.5
     container_name: php-otp-microservice-app
     roles:
       - softasap.sa-php-container
     volumes:
         - "$PWD/app/code:/www"
     environment:
       - XDEBUG=1
     ports:
       - 9000:9000
     dev_overrides:
       environment:
         - "DEBUG=1"
registries:
  docker:
    url: https://hub.docker.com/
    namespace: softasap
```

## Application Image Build

Process is very close to running ansible play over hosts.
You specify project name, path to the roles, and observing result.

In our case .project-name contains `php-otp-microservice`

```shell
#!/bin/sh

set -e

GREEN="$(tput setaf 2)"
RESET="$(tput sgr0)"

PROJECT_NAME=`cat .project-name`

# echo "${GREEN} Building conductor image ${RESET}"
# ansible-container build

echo "${GREEN} Building ${PROJECT_NAME} ${RESET}"
ansible-container --debug --project-name ${PROJECT_NAME} build --roles-path ./roles/ -- -vvv
```

If everything is Ok, you will see mix of the output that you typicallly see from Dockerfile build as well as ansible output when you run ansible play. First conductor image is being built, and on later stage your application image.

What is good - ansible container takes care on garbage, so the resulting image might be small enough.

If everything is not ok: well, ansible-container might contain bugs, perhaps you spotted one of them.

Typical troubleshouting:

- Check error message - perhaps you would see obvious reason.
Example: if you see magic
```
    config.status: executing libtool commands
    error: [Errno 2] No such file or directory

    ----------------------------------------
Command "/usr/bin/python -u -c "import setuptools, tokenize;__file__='/tmp/pip-build-nVlm3E/pynacl/setup.py';f=getattr(tokenize, 'open', open)(__file__);code=f.read().replace('\r\n', '\n');f.close();exec(compile(code, __file__, 'exec'))" install --record /tmp/pip-RGQAEv-record/install-record.txt --single-version-externally-managed --compile" failed with error code 1 in /tmp/pip-build-nVlm3E/pynacl/
```
So you might be lucky enough to understand reasoning.
For example above, in reality this means, that your base image misses `make` tool installed, which somehow is supposed by `ansible-container` :)

- Ensure all referenced images exist and are recent. In example above:
```
docker pull alpine:3.5
docker pull nginx:alpine
```
- if previous step still results to failure you might also try to install ansible-container python package from develop, perhaps issue is already fixed in develop

```
git clone https://github.com/ansible/ansible-container.git
# In case of outdated setuptool
# pip install --upgrade setuptool
pip install -e .[docker,openshift]
```

From my experience - I had to implement base image for conductor base over Docker images controlled by myself. At least you would be aware what is installed and how that can be fixed.

Mentioned custom image for conductor to fix mentioned missing make tool.
```
FROM softasap/alpine:python-2.7-35-0.0.1

RUN apk add --update make gcc g++ linux-headers libgcc libstdc++ \
    && apk add --update libffi-dev musl-dev python-dev openssl-dev
```

If process completed successfully, you would see smth like
```
PLAY RECAP *********************************************************************
php                        : ok=25   changed=17   unreachable=0    failed=0
...
Conductor terminated. Cleaning up.
```

Let's examine build artifacts - as you see we have compact enough application image and a way hugher conductor image used to build one.
```
docker images                                                                                                                 
REPOSITORY                                          TAG                   IMAGE ID            CREATED             SIZE
php-otp-microservice-php                            20170902153731        e5e5373a4b1f        3 minutes ago       45.7MB
php-otp-microservice-php                            latest                e5e5373a4b1f        3 minutes ago       45.7MB
php-otp-microservice-conductor                      latest                3ae8a5261414        4 minutes ago       463MB
```

## Test run

ansible-container's run command is used to start application locally

```
#!/bin/sh
PROJECT_NAME=`cat .project-name`
ansible-container --debug --project-name ${PROJECT_NAME} run --roles-path ./roles/ -- -vvv
```

In success scenario, it will execute. But unfortunately situation changes rapidly.
At a moment of the article writing I get 
```
Unable to load docker-compose. Try `pip install docker-compose`. Error: cannot import name splitdrive
```

thus workaround to test the build would be to create docker-compose.yml, basing on information in play generated into
`ansible-deployment`

```
---
version: '2'
services:
  nginx:
    image: nginx:alpine
    ports:
    - 8080:80
    volumes:
    - "${PWD}/app/nginx/site.conf:/etc/nginx/conf.d/default.conf"
    volumes_from:
    - php
  php:
    command: php-fpm
    entrypoint:
    - docker-php-entrypoint
    environment:
    - DEBUG=1
    image: php-otp-microservice-php:20170902153731
    ports:
    - 9000:9000
    volumes:
    - "${PWD}/app/code:/www"
    working_dir: "/www"
```


ansible-container's stop command is used to stop running application.

```
#!/bin/sh
PROJECT_NAME=`cat .project-name`
ansible-container --debug --project-name ${PROJECT_NAME} stop
```

## Points of Interest
