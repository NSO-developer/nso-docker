

# NSO in Docker

![img](./nso-in-docker-logo.png)

NOTE: Official Cisco NSO container images are offered for download from https://software.cisco.com, which is entirely different from NSO in Docker.

NSO in Docker is an open-source project that enables users to run NSO in Docker easily.

## Downloading NSO in Docker for internal Cisco users

For internal Cisco users, ready made container images built from this repository are available at <https://containers.cisco.com/organization/nso-docker>

-   use with NID skeletons:
    -   `export NSO_IMAGE_PATH=containers.cisco.com/nso-docker/`
    -   `export NSO_VERSION=5.6.3` (or whatever version you want!)


# NSO in Docker for development and production

This repository contains all you need to build Docker images out of Cisco NSO. It produces two Docker images;

-   a production image
    -   stripped of documentation and similar to make it small
    -   use this as a base image in the Dockerfile for your production container image
        -   add your own packages on top
-   a development image
    -   contains Java compiler and other useful tools
    -   can be used directly to compile packages and similar

The development image can be used immediately, for example as the image for a CI docker container runner to use for running CI jobs that involve compilation of NSO packages and similar. The production image is intended to be used as a base image on which you add your own packages, like NEDs and your service packages, to produce a final image for your environment.


# How and why?

There are many reasons for why Docker and containers in general might be good for you. The main drivers for using Docker with NSO lies around packaging, ensuring consistency in testing and production as well as making it simple and convenient to create test environments.

-   build a docker image out of a specific version of NSO and your packages
    -   distributed as one unit!
    -   you test the combination of NSO version X and version Y of your packages
        -   think of it as a &ldquo;version set&rdquo;
    -   the same version set that is tested in CI is deployed in production
        -   guarantees you tested same thing you deploy
    -   conversely, using other distribution methods, you increase the risk of testing one thing and ending up deploying something else - i.e. you didn&rsquo;t really test what you use in production
-   having NSO in a container makes it easy to start
    -   simple to test
    -   simple to run in CI
    -   simple to use for development
-   benefits of NSO in Docker ecosystem
    -   easy to run netsim or virtual routers for testing
    -   creating testing and development environments (testenv) that are shareable
        -   it is key for an efficient development team to have organized and shareable environments for development
-   you do NOT need Kubernetes, Docker swarm or other fancy orchestration
    -   run Docker engine on a single machine

It&rsquo;s also worth noting that using Docker does not mean you have to replace all of your current infrastructure. If you are currently using OpenStack or some system that primarily deals with virtual machines you don&rsquo;t have to rip this out. On the particular VM that runs NSO you can simply install Docker and have a single machine Docker environment that runs NSO. You are using Docker for the packaging features!

Yet another alternative is to use Docker for development and CI and when it&rsquo;s time to deploy to production you use something entirely different. Docker images are glorified tar files so it is possible to extract the relevant files from them and deploy by other means.


# Use cases & guides

NSO in Docker is not just two Docker container images but rather an ecosystem - the NID (Nso In Docker) ecosystem, which is about a way of working and approaching problems. The NID ecosystem defines the concept of common development and test environments. It uses the base NSO images as the foundation to allow building:

-   NED repository
    -   including running the NED as a netsim
    -   having a standardized test and development environment
-   package repository
    -   service or other package repository
    -   including testing of the repository
-   NSO system repository
    -   a repository encompassing an entire NSO system
    -   use NSO service packages
    -   include NEDs and other packages built on other repositories
    -   write tests in a simple way
    -   having a standardized test and development environment
-   common for all NID skeletons
    -   easily implement tests for
    -   test across multiple NSO versions
    -   share the definition of a development environment among colleagues
        -   provide a simple to use and familiar starting point and ergonomics
        -   drastically shorten time from branching feature branch to writing and testing first lines of code
        -   leverage same topology for development and testing

See the [NID skeletons](./skeletons/) for how to get started developing in the NID ecosystem.


# Prerequisites

NSO in Docker runs on:

-   Linux
-   Mac OS X, see [Mac OS X support](#org91ffb29) for more information
-   Windows, see [Windows Support](#orgbcd49a9) for more information

To build these images, you need:

-   Docker
-   Make
-   realpath

Install with:

-   Debian: `apt install coreutils make`
-   Mac OS X: `brew install coreutils`
-   see <https://docs.docker.com/get-docker/> for installation instructions for Docker

If you want to run the test suite you also need:

-   expect
-   sshpass


# Usage

The ideal scenario would be to ship prebuilt Docker images containing NSO but as legal requirements prevent that, this is the second best option. This repository contains recipes that you can use to produce Docker images yourself. Just add <del>water</del> Cisco NSO ;)


## Building


### Manually building Docker images on your local machine

-   Clone this repository to your local machine
    -   `git clone https://gitlab.com/nso-developer/nso-docker.git`
-   Download Cisco NSO
    -   go to <https://developer.cisco.com/docs/nso/#!getting-nso/getting-nso> and click the &ldquo;NSO 5.x Linux&rdquo; link to download NSO
-   If the file ends with `.signed.bin`, it is a self-extracting archive that verifies a signature, execute it to produce the installer
    -   for example running `bash nso-5.3.linux.x86_64.signed.bin` will produce a number of files, among them the install `nso-5.3.linux.x86_64.installer.bin`
-   Place the `nso-5.x.linux.x86_64.installer.bin` file in `nso-install-files/` in this repository
-   run `make` in repository root directory, which will build Docker images out of all the NSO install files found
    -   **NOTE**: running docker commands, which are invoked by `make`, typically require root privileges or membership in the `docker` group
    -   this runs `make build-all` which will build images for all found NSO versions
    -   use `NSO_VERSION=5.3 make build` to build for a specific version
-   verify your new images are built with `docker images` which should look something like the following
    -   **NOTE**: the docker images are tagged with a suffix
        -   the suffix will be your username, for example `cisco-nso-base:5.3-kll` if your username is `kll`
        -   the suffix is to avoid overwriting a version tag, like `cisco-nso-base:5.3`, before the image has been tested and determined to be a good build
        -   run `make tag-release` to also add a docker tag without the suffix, like `cisco-nso-base:5.3`

    docker images

    REPOSITORY                   TAG                 IMAGE ID            CREATED             SIZE
    kll-test-cisco-nso-5.3-kll   latest              999b88b099ed        16 hours ago        550MB
    <none>                       <none>              14806a997e24        16 hours ago        1.15GB
    cisco-nso-base               5.3-kll             8ed0cb9decad        16 hours ago        550MB
    <none>                       <none>              1c332a6ffb25        16 hours ago        505MB
    cisco-nso-dev                5.3-kll             d94c42ccd65f        16 hours ago        1.15GB
    debian                       buster              b5d2d9b1597b        11 days ago         114MB

Run `make tag-release` and provide the version to tag using the variable `NSO_VERSION`:

    make NSO_VERSION=5.3 tag-release
    docker images

    docker tag cisco-nso-dev:5.3-kll cisco-nso-dev:5.3
    docker tag cisco-nso-base:5.3-kll cisco-nso-base:5.3
    REPOSITORY                   TAG                 IMAGE ID            CREATED             SIZE
    kll-test-cisco-nso-5.3-kll   latest              999b88b099ed        16 hours ago        550MB
    <none>                       <none>              14806a997e24        16 hours ago        1.15GB
    cisco-nso-base               5.3                 8ed0cb9decad        16 hours ago        550MB
    cisco-nso-base               5.3-kll             8ed0cb9decad        16 hours ago        550MB
    <none>                       <none>              1c332a6ffb25        16 hours ago        505MB
    cisco-nso-dev                5.3                 d94c42ccd65f        16 hours ago        1.15GB
    cisco-nso-dev                5.3-kll             d94c42ccd65f        16 hours ago        1.15GB
    debian                       buster              b5d2d9b1597b        11 days ago         114MB


### Automatically building Docker images using Gitlab CI

-   Clone this repository to your local machine
    -   `git clone https://gitlab.com/nso-developer/nso-docker.git`
-   Download Cisco NSO
    -   go to <https://developer.cisco.com/docs/nso/#!getting-nso/getting-nso> and click the &ldquo;NSO 5.x Linux&rdquo; link to download NSO
-   If the file ends with `.signed.bin`, it is a self-extracting archive that verifies a signature, execute it to produce the installer
    -   for example running `bash nso-5.3.linux.x86_64.signed.bin` will produce a number of files, among them the install `nso-5.3.linux.x86_64.installer.bin`
-   Place the `nso-5.x.linux.x86_64.installer.bin` file in `nso-install-files/` in this repository
-   commit file(s) in `nso-install-files/` using git LFS and push
    -   `git add nso-install-files/*`
    -   `git commit nso-install-files -m "Add NSO install files"`
        -   it is a good practice to add the files one by one and write the version you added in the commit message, like `Add NSO install file for v4.7.5`
    -   `git push -u origin master`
    -   CI will now build the docker images for you
        -   naturally provided you first setup CI
-   verify your new images are built by going to the container repository in Gitlab viewing the list of container images
    -   the docker tag for built images consists of the NSO version number and the CI pipeline id, for example `cisco-nso-base:5.3-7583729` for NSO version `5.3` and pipeline id `7583729`
    -   CI builds on the `master` branch will in addition be tagged with just the NSO version, that is `cisco-nso-base:5.3`, after passing tests


### Alternative for providing NSO install files into CI runner

The above method involves committing the NSO install files to this git repository (your clone of it). This means the repository must be private so that you don&rsquo;t leak the NSO install files nor the produced Docker images. There are a number of reasons for why this setup might not be ideal;

-   you have an open source public repo and wish to run CI publicly
-   LFS doesn&rsquo;t work with your choice of code hosting
-   NSO install files are too big or you just don&rsquo;t like LFS

There is an alternative. The path in which the build process looks for the NSO install file(s) is specified by `NSO_INSTALL_FILES_DIR`. The default value is `nso-install-files/`, i.e. a directory relative to the root of the repository. The standard way of delivering the NSO install files, as outlined in the process above, is to place the NSO files in that directory. The alternative is to change the `NSO_INSTALL_FILES_DIR` variable. Note how you can set this environment variable through the GitLab CI settings page under variables. You do **not** need to commit anything. In case you are running Gitlab CI with the `docker` runner, add the path to the list of `volumes`, for example:

    [[runners]]
      name = "my-runner"
      url = "https://gitlab.com/"
      token = "s3cr3t"
      executor = "docker"
      [runners.docker]
        tls_verify = false
        image = "debian:buster"
        privileged = false
        disable_entrypoint_overwrite = false
        oom_kill_disable = false
        disable_cache = false
        volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock", "/data/nso-install-files:/nso-install-files"]
        shm_size = 0

The path `/data/nso-install-files` on the host machine becomes available as `/nso-install-files/` in the CI build docker containers and by specifying that path (`/nso-install-files`) using the CI variable settings, the job will now pick up the NSO images from there. This is how the public repo at <https://gitlab.com/nso-developer/nso-docker> works. It allows us to host all code in public, run CI tests in public yet not reveal the NSO install file as required by its EULA.


## Running


### Platform architecture

NSO is compiled for Linux on x86<sub>64</sub> / amd64. If you are using a different CPU architecture, like the Apple M1 silicon, you must run the container with the additional argument `--platform=linux/amd64`. For example, starting NSO standalone for testing would be:

    docker run -itd --platform=linux/amd64 --name nso-dev1 my-prod-image:12345

Using the `--platform=linux/amd64` argument when the native architecture is already amd64 is harmless and doesn&rsquo;t incur any emulation penalty or similar. The only drawback is that older versions of Docker does not support the `--platform` argument and throws an error. In the Makefiles in this repository and in the repository skeletons, the use of the `--platform` argument is conditioned. Docker running on any architecture that is not `x86_64` implies that it is new enough to also support the `--platform` argument.

    ifneq ($(shell uname -m),x86_64)
    DOCKER_PLATFORM_ARG ?= --platform=linux/amd64
    endif


### Run standalone for testing

-   if you built a production image, i.e. using base image from this repo and adding in your own packages
-   run a standalone container
-   no persistent volume - since we are doing testing we don&rsquo;t need to survive a restart
-   use docker networking - connect to other things running in docker, like netsim etc

    docker run -itd --name nso-dev1 my-prod-image:12345


### Run for development

-   mount the source code directory into the container
-   makes it possible to use compiler etc in the container
-   avoid installing compilers and other tools directly on your computer

    docker run -itd --name nso-dev1 -v $(pwd):/src cisco-nso-dev:5.2


### Run for production

-   with a production image, i.e. using the base image from this repo and adding in your own packages
-   use shared volume, mounted at `/nso`, to persist data across restarts
    -   CDB (NSO database)
    -   SSH & SSL keys
    -   NETCONF notification replay
    -   rollbacks
    -   backups
-   optionally mount a shared volume at `/log` to persist NSO logs
    -   if remote (syslog) logging is used there is little need to persist logs
    -   if local logging, then persisting logs is a good idea
-   possibly use &#x2013;net=host to share IP address with host machine
    -   makes it easier to handle connectivity

This uses the `--net=host` option to let the container live in the hosts networking namespace. This means that it binds to the IP address of the (virtual) machine it is running on. NSO is configured to expose the CLI over SSH on port 22. If you have SSH running on the VM, there will be a collision when using `--net=host`. To avoid port collision you can reconfigure NSO to listen on a different port by setting the `SSH_PORT` environment variable. Also note that we use a shared volume for logs. `/log` inside the container contains the logs and you can access them outside the container in `/data/nso-logs`.

    docker run -itd --name nso -v /data/nso:/nso -v /data/nso-logs:/log --net=host -e SSH_PORT=2024 my-prod-image:12345


## NSO configuration management

There are multiple approaches for how to deal with `ncs.conf` in NSO in Docker;

1.  idiomatic container approach with select options being configurable via environment variables
2.  feed in existing `ncs.conf` using one of two approaches
    1.  directly mount `ncs.conf` to `/etc/ncs/ncs.conf` in the container
    2.  place `ncs.conf` on the volume mounted to `/nso` in the container, under `/nso/etc/ncs.conf`


### Injecting ncs.conf as a directly mounted file at /etc/ncs/ncs.conf

This approach is quite straight forward. Simply mount up a configuration file to `/etc/ncs/ncs.conf`.

    docker run -itd --name nso -v /data/nso-config/my-nso-config.conf:/etc/ncs/ncs.conf -v /data/nso:/nso -v /data/nso-logs:/log --net=host my-prod-image:12345

The normal configuration mangling will NOT be applied to the mounted `/etc/ncs/ncs.conf`. It is not recommended to enable mangling a directly mounted `ncs.conf`. It can be forced to run by setting `MANGLE_CONFIG=true`, for example:

    docker run -itd --name nso --env MANGLE_CONFIG=true -- -v /data/nso-config/my-nso-config.conf:/etc/ncs/ncs.conf -v /data/nso:/nso -v /data/nso-logs:/log --net=host my-prod-image:12345

NOTE: the mangling will be directly applied to the mounted file and modify it. Many of the mangling operations are not idempotently implemented, so this will likely break things. If you want to supply a configuration file and mangle it on startup, you probably want to mount it to `/etc/ncs/ncs.conf.in`.

It is entirely up to you to manage your `ncs.conf` and make sure that it is correct. See the section [6.3.4](#org7c11b74).


### Injecting ncs.conf through a persistent volume

Place your `ncs.conf` in a `etc` directory on the volume that is mounted to `/nso` on the NSO container. From inside the container, the path should be `/nso/etc/ncs.conf`.

Here is en example where we start NSO with no `ncs.conf`, so that one will be generated. We then copy this file over, edit it and restart NSO to use the new `ncs.conf` from our volume.

    # start NSO, which will generate a ncs.conf
    docker run -itd --name nso -v /data/nso:/nso -v /data/nso-logs:/log --net=host my-prod-image:12345
    # copy over ncs.conf to the volume
    docker exec -it nso bash -lc 'cp /etc/ncs/ncs.conf /nso/etc/ncs.conf'
    # manually edit /data/nso/etc/ncs.conf (path that is bind mounted to the container)
    #
    # stop NSO
    docker rm -f nso
    # start NSO again, this time the config from /data/nso/etc/ncs.conf will be used
    docker run -itd --name nso -v /data/nso:/nso -v /data/nso-logs:/log --net=host my-prod-image:12345

The normal configuration mangling will NOT be applied to `ncs.conf` injected though a persistent volume. It can be enabled to run by setting `MANGLE_CONFIG=true`, for example:

    docker run -itd --name nso --env MANGLE_CONFIG=true -- -v /data/nso:/nso -v /data/nso-logs:/log --net=host my-prod-image:12345

Unlike for a directly mounted `ncs.conf`, the mangling will not be persisted as `/nso/etc/ncs.conf` is first copied to `/etc/ncs/ncs.conf` before being mangled. As per the above example, it can be persisted by manually copying the file, or select sections of it.


### Idiomatic container handling of ncs.conf

On startup, when neither `/etc/ncs/ncs.conf` (a directly mounted config) or `/nso/etc/ncs.conf` exists, NSO in Docker will default to starting from the stock config from the installed NSO version, which is stored in the container image at `/etc/ncs/ncs.conf.in`. This configuration is copied to `/etc/ncs/ncs.conf` and then mangled - applying a number of modifications to the configuration, before NSO is started. These modifications are performed by the startup script `/etc/ncs/pre-ncs-start.d/50-mangle-config.sh`, which in turn takes options through the following environment variables:

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">Environment variable</th>
<th scope="col" class="org-left">Type</th>
<th scope="col" class="org-left">Default</th>
<th scope="col" class="org-left">Description</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left"><code>MANGLE_CONFIG</code></td>
<td class="org-left">boolean</td>
<td class="org-left">-</td>
<td class="org-left">Force enabling or disabling of config mangling</td>
</tr>


<tr>
<td class="org-left"><code>PAM</code></td>
<td class="org-left">boolean</td>
<td class="org-left">false</td>
<td class="org-left">Enable PAM instead of local auth in NSO (AAA)</td>
</tr>


<tr>
<td class="org-left"><code>HA_ENABLE</code></td>
<td class="org-left">boolean</td>
<td class="org-left">false</td>
<td class="org-left">Enable HA</td>
</tr>


<tr>
<td class="org-left"><code>HTTP_ENABLE</code></td>
<td class="org-left">boolean</td>
<td class="org-left">false</td>
<td class="org-left">Enable HTTP web UI</td>
</tr>


<tr>
<td class="org-left"><code>HTTPS_ENABLE</code></td>
<td class="org-left">boolean</td>
<td class="org-left">false</td>
<td class="org-left">Enable HTTPS (TLS) web UI</td>
</tr>


<tr>
<td class="org-left"><code>SSH_PORT</code></td>
<td class="org-left">uint16</td>
<td class="org-left">22</td>
<td class="org-left">Set port for SSH to listen on</td>
</tr>


<tr>
<td class="org-left"><code>CLI_STYLE</code></td>
<td class="org-left">enum</td>
<td class="org-left">j</td>
<td class="org-left">Configure the default CLI style to &rsquo;j&rsquo; or &rsquo;c&rsquo;</td>
</tr>


<tr>
<td class="org-left"><code>XPATH_TRACE</code></td>
<td class="org-left">boolean</td>
<td class="org-left">false</td>
<td class="org-left">Enable XPath tracing</td>
</tr>


<tr>
<td class="org-left"><code>AUTO_WIZARD</code></td>
<td class="org-left">boolean</td>
<td class="org-left">true</td>
<td class="org-left">Disable CLI auto-wizard by setting to &rsquo;false&rsquo;</td>
</tr>
</tbody>
</table>

Injecting a `ncs.conf` and enabling configuration mangling will also accept the same environment variables as input.

As we start with the `/etc/ncs/ncs.conf.in` as provided by the NSO version installed in our image, our starting point will look somewhat different. For example, if we build a container image based on NSO 5.2 we will get the default `ncs.conf` that comes with `5.2`. Any updates to the `ncs.conf` shipped with NSO will find its way into the container image. 


### Writing your own ncs.conf

If you write your own `ncs.conf` from scratch, you should pay extra attention to certain aspects that are somewhat different in NSO in Docker compared to a classic install;

-   load packages from `/var/opt/ncs/packages` (in the container image) rather than from the run-dir (which is at `/nso/run`)
-   use of custom Python-VM startup script that supports Python virtualenvs
-   ensure you refer to the persisted &ldquo;support&rdquo; files in the `/nso` volume
    -   `ncs.crypto_keys`
    -   SSH keys
    -   SSL cert


### Modifying the NSO configuration file ncs.conf

The standard Docker run script (`run-nso.sh`) looks for files that ends with `.sh` in `/etc/ncs/pre-ncs-start.d/` and `/etc/ncs/post-ncs-start.d/` and will run any scripts found before or after starting NSO. This facility is used to modify the `ncs.conf` configuration file before NSO is started. `/etc/ncs/pre-ncs-start.d/50-mangle-config.sh` performs the necessary modifications. Since `ncs.conf` is a structured XML document, it primarily uses `xmlstarlet` to perform modification operations on the configuration file.

You can further modify the `ncs.conf` configuration file by adding your own startup script in `/etc/ncs.pre-ncs-start.d/` or potentially modifying `/etc/ncs/pre-ncs-start.d/50-mangle-config.sh`. Since the configuration file is an XML document, modification is best done through an XML aware tool. If you write your own script, be sure to honor that when the `MANGLE_CONFIG` variable is set to false, you should not modify the configuration.


# Docker image tags

The Docker images produced by this repo per default carry a unique tag based on the CI<sub>JOB</sub><sub>ID</sub> variable set by Gitlab CI, for example `registry.gitlab.com/nso-developer/nso-docker/cisco-nso-dev:31337` where `31337` is the value from `CI_JOB_ID`.

In addition, if the job is built on the default branch (typically `main` or `master`), it will also receive a tag based on the NSO version it contains. For example, if the previously mentioned image is based on NSO 5.2.1 and was built from the default `main` branch it would also get the tag `registry.gitlab.com/nso-developer/nso-docker/cisco-nso-dev:5.2.1`. This makes it possible for other repositories to use the `5.2.1` tag to always refer to the latest build of `5.2.1`.

Do note that the example image URLs used above would be the result of the default configuration for the official origin repository for the `nso-docker` project. However, as the official repo CI builds happen in a public environment, the resulting images can&rsquo;t be pushed as it would effectively publish this is per the default configuration and although the example URL follows that for the official origin repo for the nso-docker project.

It is recommended to use a nightly job to produce new images every night that include the latest security patches and similar to the base images. Do note however that this also means that updates to packages will happen and that could have negative consequences if they are not fully backwards compatible. These images are based on Debian stable but for example, pylint has been known to include additional lints in newer version and so new version of the image could include change like this which lead to unintended results.

For a truly deterministic environment, downstream repositories that rely on these Docker images should be based on the unique tag and consequently be updated with the same cadence as new images are built.


# Exposed ports

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-right" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">Protocol</th>
<th scope="col" class="org-right">Port</th>
<th scope="col" class="org-left">Use</th>
<th scope="col" class="org-left">Config var</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">TCP</td>
<td class="org-right">22</td>
<td class="org-left">SSH</td>
<td class="org-left"><code>SSH_PORT</code></td>
</tr>


<tr>
<td class="org-left">TCP</td>
<td class="org-right">80</td>
<td class="org-left">HTTP</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">TCP</td>
<td class="org-right">443</td>
<td class="org-left">HTTPS</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">TCP</td>
<td class="org-right">830</td>
<td class="org-left">NETCONF</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">TCP</td>
<td class="org-right">4334</td>
<td class="org-left">NETCONF call-home</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">TCP</td>
<td class="org-right">4570</td>
<td class="org-left">NSO HA</td>
<td class="org-left">&#xa0;</td>
</tr>
</tbody>
</table>

It is possible to reconfigure the port that SSH uses by setting the `SSH_PORT` variable to the wanted value.


# Admin user

An admin user can be created on startup by the run script in the container. There are three environment variables that control the addition of an admin user;

-   `ADMIN_USERNAME`: username of the admin user to add, default is `admin`
-   `ADMIN_PASSWORD`: password of the admin user to add
-   `ADMIN_SSHKEY`: private SSH key of the admin user to add

As `ADMIN_USERNAME` already has a default value, only `ADMIN_PASSWORD` or `ADMIN_SSHKEY` need to be set in order to create an admin user. For example:

    docker run -itd --name nso -e ADMIN_PASSWORD=foobar my-prod-image:12345

This can be very useful when starting up a container in CI for testing or when doing development. It is typically not required in a production environment where there is a permanent CDB that already contains the required user accounts.

Also note how this only adds a user. If you are using a permanent volume for CDB etc and start the NSO container multiple times with different `ADMIN_PASSWORD` then the last run will effectively overwrite the older password. However, if you change `ADMIN_USERNAME` between invocations then you will create multiple users! An admin user account created during the last run of NSO will **not** be removed just because `ADMIN_USERNAME` is set to a different value.


# Python VM version

These docker images default to using python3.

In NSO v5.3 and later, the python VM to use is probed by first looking for `python3`, if not found `python2` will be tried and finally it will fall back to running `python`. In earlier versions of NSO, `python` is executed, which on most systems means python2. As python2 is soon end of life, these docker images default to using `python3`.


# Backup

Backup and restore largely behaves as it normally does with `ncs-backup` as run outside of Docker.

Normally, the ncs-backup script includes the NCS<sub>CONFIG</sub><sub>DIR</sub> (defaults to /etc/ncs). SSH keys and SSL certificates are normally placed in /etc/ncs/ssh and /etc/ncs/ssl respectively. When NSO is run in a container the keys are normally provided using a persistent volume (`/nso`). These secrets are copied to the configuration dir at startup and will be included in the backup. This distinction becomes important when you restore a backup and want to store the secrets on the persistent volume.


## Taking a backup

To take a backup, simply run `ncs-backup`. The backup file will be written to `/nso/run/backups`.


## Restoring from a backup

Backups created with `ncs-backup` contain all files necessary to run NSO, not only limited to data and packages, but also startup configuration and secrets. The latter are restored to NCS<sub>CONFIG</sub><sub>DIR</sub> (defaults to /etc/ncs). In NSO in Docker these files are normally stored on a persistent volume (`/nso`). The restore procedure described below use mounts a subdirectory in the persistent shared volume to `/etc/ncs` in the container to ensure the configuration files are restored to the persistent volume.

To restore a backup, NSO must not be running. As you likely only have access to the `ncs-backup` tool and the volume containing CDB and other run time state from inside of the NSO container, this poses a slight challenge. Additionally, shutting down NSO will terminate the NSO container.

What you need to do is shut down the NSO container and start a new one with the same persistent shared volume mounted but with a different command. Instead of running the `/run-ncs.sh` which is the normal command of the NSO container, you should run something that keeps the container alive but doesn&rsquo;t start NSO, for example `read DUMMY` (it&rsquo;s a bash builtin command so still have to run bash). A full docker command could look like:

    docker run -itd --name nso -v /data/nso:/nso -v /data/nso/etc:/etc/ncs -v /data/nso-logs:/log --net=host my-prod-image:12345 bash -lc 'read DUMMY'

You now have the NSO container running but without NSO itself. Get a shell in the container with

    docker exec -it nso bash -l

Then run the ncs-backup restore command, for example:

    ncs-backup restore /nso/run/backups/ncs-4.7.5@2019-10-07T14:41:02.backup.gz

Or if you want to automate the whole process slightly you could do it all using docker exec and non-interactively:

    docker exec -it nso bash -lc 'ncs-backup restore /nso/run/backups/ncs-4.7.5@2019-10-07T14:41:02.backup.gz --non-interactively'

The restore command also restored the startup configuration to `/data/etc/ncs.conf`. This means the next time you start NSO in Docker the configuration file will be used verbatim. If you would like to keep using config mangling, remove the file from the persistent shared volume:

    rm /data/etc/ncs.conf

Restoring a NSO backup should move the current run directory (`/nso/run` to `/nso/run.old`) and restore the run directory from the backup to the main run directory (`/nso/run`). After this is done, shut down your temporary container and start the normal NSO container again as usual.


# SSH host key

NSO looks for the SSH host key in the directory `/nso/etc/ssh`. The filename differs based on the configured host key algorithm. NSO in Docker will use the RSA algorithm for host keys.

If no SSH host key exists, one will be generated. As it is stored in `/nso` which is typically a persistent shared volume in production setups, it will remain the same across restarts or upgrades of NSO.

NSO version 5.3 and newer supports ed25519 and will in fact default to using ed25519 as server host key on new installations but this behavior is suppressed for NSO in Docker and instead RSA is used as it is supported by all currently existing versions of NSO.


# HTTPS TLS certificate

NSO expects to find a TLS certificate and key at `/nso/etc/ssl/cert/host.cert` and `/nso/etc/ssl/cert/host.key` respectively. Since the `/nso` path is usually on persistent shared volume for production setups, the certificate remains the same across restarts or upgrades.

When no certificate is present, one will be generated. It is a self-signed certificate valid for 30 days making it possible to use both in development and staging environments. It is **not** meant for production. You **should** replace it with a proper signed certificate for production and it is encouraged to do so even for test and staging environments. Simply generate one and place at the provided path, for example using the following, which is the command used to generate the temporary self-signed certificate:

    openssl req -new -newkey rsa:4096 -x509 -sha256 -days 30 -nodes \
            -out /nso/etc/ssl/cert/host.cert -keyout /nso/etc/ssl/cert/host.key \
            -subj "/C=SE/ST=NA/L=/O=NSO/OU=WebUI/CN=Mr. Self-Signed"


# Logrotate and other periodic tasks (cron)

NSO places the logs in `/log` by default. NSO does not rotate the logs itself, but the installation does include a system `logrotate` configuration in `/etc/logrotate.d/ncs`. The `cron` installation in the base image schedules a `logrotate` run daily when enabled. The following environment variables control this functionality:

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">Environment variable</th>
<th scope="col" class="org-left">Type</th>
<th scope="col" class="org-left">Default</th>
<th scope="col" class="org-left">Description</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left"><code>CRON_ENABLE</code></td>
<td class="org-left">boolean</td>
<td class="org-left">true</td>
<td class="org-left">Enables cron to run entries in <code>/etc/cron.*/</code> and crontabs</td>
</tr>


<tr>
<td class="org-left"><code>LOGROTATE_ENABLE</code></td>
<td class="org-left">boolean</td>
<td class="org-left">true</td>
<td class="org-left">Enables logrotate configuration, executed by cron</td>
</tr>
</tbody>
</table>

`CRON_ENABLE` must be set to true when `LOGROTATE_ENABLE` is set to true. The startup script will report and stop startup if the condition is not satisfied.


# NSO upgrades, downgrades, YANG model changes and package modifications

As the produced Docker image contains both NSO itself and a given version of all included packages, any changes to said components will result in a new Docker image. Deploying any change, however small, means building and deploying a new Docker image. Upgrading and downgrading of NSO itself, with the packages kept static, is also based on deploying another Docker image.


## (Destructive) YANG model changes

The database in NSO, called CDB, is using YANG models as the schema for the database. It is only possible to store data in CDB according to the YANG models that define the schema.

If the YANG models are changed, in particular if nodes are removed or renamed (rename is basically a removal of one leaf and an addition of another), any data in CDB for those leaves will be removed. NSO normally warns about this when you attempt to load the new packages, for example `request packages reload` will refuse to reload the packages if nodes in the YANG model have disappeared. You would have to add the `force` argument, e.g. `request packages reload force`.

NSO in Docker will automatically reload packages on startup, using the `--with-packages-reload-force` argument to `ncs` on startup. This means that destructive model changes will be accepted without warning. It is expected that NSO in Docker is developed in an environment where there are other safe guards, such as CI testing, to catch accidental destructive model changes.


## NSO version 4 to 5 upgrade

The major new feature in NSO version 5 is what&rsquo;s known as Common Data Models or CDM, which is based on the YANG schema-mount standard (RFC8528). With it, there are changes to the CDB database files on disk. The migration from a CDB written by NSO version 4 to NSO version 5 happens automatically but first the old CDB written by NSO version 4 must be compacted, which is a manual step. However, with NSO in Docker, the startup script takes care of this for you by automatically determining at startup if NSO version 5 is being started on a CDB written by NSO version 4. If this is the case, the CDB on disk is compacted.

NSO 5 requires that packages, in particular NEDs, be compiled for CDM. Thus, upgrading to NSO 5 typically also involves upgrading one or more NEDs. In the process of changing NEDs and upgrading NSO there is the risk of inadvertently making model changes that lead to data loss, in which case the upgrade process needs to be reattempted. The overall upgrade process is something along the lines of:

-   take backup of CDB (in NSO 4 format)
-   compact CDB
-   take backup of CDB (in NSO 5 format)
-   start NSO 5
    -   verify data integrity
    -   if model / data inconsistencies have lead to data loss
        -   restore from backup that contains NSO 5 compacted CDB
        -   rectify packages
        -   start NSO 5 with new packages
        -   repeat until done

Multiple attempts might be necessary to get everything to load and upgrade correctly. CDB compaction can take some time (depending on the size of CDB). By restoring from a backup of a compacted CDB, we avoid having to compact CDB for every retry.

In a production setting with a structured approach to development and operations, the recommendation would be to take a backup of CDB from production and move to a development machine where the above steps can be executed. Preferably also incorporating not just the NED / package changes into CI but also including testing of the CDB upgrade. The upgrade is thus tested in development & CI before being attempted on the production deployment machines. While we might use a compacted CDB to speed up the development and testing of the upgrade, as outlined above, the actual upgrade of the production system will only happen once inside of an NSO container in an unsupervised fashion, which is why startup script of NSO in Docker will automatically determine the CDB version + NSO version and, if deemed necessary, perform CDB compaction.


# Extending the Docker image

There are multiple approaches to extending the functionality of the NSO docker image.


## Default CDB data

When NSO starts up with no pre-existing CDB, it will load the files placed in `/nid/cdb-default/` in the container image. Simple place an XML file in `/nid/cdb-default/` to have its content loaded on first startup.


## Running scripts on startup

The standard Docker run script (`run-nso.sh`) looks for files that ends with `.sh` in `/etc/ncs/pre-ncs-start.d/` and `/etc/ncs/post-ncs-start.d/` and will run any scripts found before or after starting NSO. `ncs --wait-started` is used to wait for NSO to start. If you want to modify the configuration file, produce some XML files to be read into CDB on startup or similar, you can write a script for that and place it in the relevant startup directory (typically before NSO is started).

In other situations you want to run scripts that load or modify some configuration in NSO (CDB) somehow, which might be better suited to be placed in `/etc/ncs/post-ncs-start.d` (though don&rsquo;t mistake these capabilities for what CDB upgrade logic and similar offers). For example, it is possible to start another process in the same container and if that process is dependent upon NSO having started, placing the script in `/etc/ncs/post-ncs-start-d/` is a convenient approach as those scripts are only started after NSO have started up (as determined by `ncs --wait-started`).


# NSO packages mounted on a volume

The standard practice is to use the cisco-nso-base image as a base image and build your own Docker image that includes the packages you want. Thus the packages are part of the image and can readily be tested in CI and you have a certain guarantee on consistency: the same thing you tested in CI is also what you will run in production. If you upgrade NSO version, you get a completely new container image with new versions of your packages compiled for the correct NSO version!

However, it is also possible to load packages by placing them in the `packages/` directory in the run directory. NSO has both `/var/opt/ncs/packages` and `/nso/run/packages` in the load path. In order to persist data across restarts of the container, a shared volume or similar is typically mounted to `/nso` and since the run directory is `/nso/run`, it will reside on this shared volume. Simply places your packages there and they will be loaded by NSO on startup.

Do however note that you now have to ensure that the packages in that directory are compiled for the version of NSO that you are running. Since they are locally loaded packages, this can no longer be ensured through CI.


# Healthcheck

The production-base image comes with a basic Docker healthcheck. It is using ncs<sub>cmd</sub> to get the phase that NSO is currently in. Only the result status, i.e. if ncs<sub>cmd</sub> was able to communicate with the `ncs` process or not, is actually observed. This tells us whether the `ncs` process is responding to IPC requests.

As far as monitoring NSO goes, this is a very basic check. Just a tad above the basic process check, i.e. that the `ncs` process is actually alive, which is the most basic premise of production-base image.

More advanced and deeper looking healthchecks could be conceived, for example by observing locks and measuring the time a certain lock has been held, but it is difficult to find a completely generic set of conditions for flagging NSO as healthy or unhealthy based on that. For example, if a transaction lock has been held for 5 hours, is that healthy or not? In most situations, that would be an abnormally long transaction, but does it constitute an unhealthy state? In certain operational environments it could be normal with that long transactions (for example a batch import of some data). Marking the container as unhealthy and potentially restarting it as a consequence would only make things worse.

We really want to measure some form of progress, even if that progress is just internal. A five hours transaction is fine as long as we are continuously making progress. However, there are currently no such indicators available and so the healthcheck observes the rather basic operation of the IPC listener.


# Make targets

There are multiple make targets for building an NSO docker image.


## Based on NSO version

Assuming the NSO install file has been placed in the `NSO_INSTALL_FILES_DIR` (per default `nso-install-files/`), you can run:

    make NSO_VERSION=5.2.1 build

To produce a docker image based on NSO 5.2.1. It requires that the corresponding installer file is present, i.e. `nso-install-files/nso-5.2.1.linux.x86_64.installer.bin`.


## Based on complete path to NSO installer file

You can use the `build` target to build a Docker image out of an NSO installer. It requires that you specify the complete path to the NSO
installer file, for example:

    make FILE=/home/foo/nso-docker/nso-install-files/nso-5.2.1.linux.x86_64.installer.bin build-file


## For all NSO installer files in NSO<sub>INSTALL</sub><sub>FILES</sub><sub>DIR</sub>

To build docker images for all the NSO installer files present in the NSO installer directory, (specified by `NSO_INSTALL_FILES_DIR`), you can run:

    make build-all

There are targets to run tests that correspond with the above;

-   test-version
-   test
-   test-all

They require the same variables to be set as their corresponding build target described above.


# GitLab CI runner

**NOTE**: Using a Gitlab CI runner as described in this section has different security implications than what is normally associated with using containers for CI. See the Security sub-heading.

In order to build the CI pipeline as defined for this repository you need GitLab and a GitLab CI runner. It is possible to use the free and public gitlab.com in order to host the code but you have to provide your own Gitlab CI runner. While you have access to CI runners simply by using gitlab.com to host your code, their capabilities don&rsquo;t match what is needed in order to build this project. Fortunately, Gitlab as a product makes it very simple to connect your own CI runner to any Gitlab instance, including the public gitlab.com one.

1.  Get a VM or a physical machine to run your CI runner.
2.  Install Debian on said machine.
3.  Follow the guide on <https://docs.gitlab.com/runner/install/linux-repository.html> to install the Gitlab CI runner on your machine
4.  Follow the guide at <https://docs.gitlab.com/runner/register/> on how to register your runner with Gitlab
5.  Expose the docker control socket in the gitlab runner configuration

Here&rsquo;s a configuration file for gitlab ci runner. Note the `volumes` setting which includes `/var/run/docker.sock` - this exposes the Docker control socket to the containers run by the CI runner which enables the containers to start *sibling* containers.

    [[runners]]
      name = "my-runner"
      url = "https://gitlab.com/"
      token = "s3cr3t"
      executor = "docker"
      [runners.docker]
        tls_verify = false
        image = "debian:buster"
        privileged = false
        disable_entrypoint_overwrite = false
        oom_kill_disable = false
        disable_cache = false
        volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
        shm_size = 0

You naturally need to use your token and not literally `s3cr3t`. The token is written when you do the runner registration per the guide referenced above.


## Security

Note that exposing the Docker control socket has security implications. Containers as run by the CI runner normally provide isolation such that CI jobs are contained within the container and are unable to access anything outside of the container. By exposing the docker control socket, the CI jobs can start new containers, including starting a privileged one, which means it has root access on the host machine and enables escaping the container entirely. Do not grant access to your project or CI runner to anyone you do not trust. For example, someone that is able to create a branch on your repository can write a Gitlab CI configuration file that instructs the CI runner to run a privileged container and then gain access to the CI runner machine itself.


# Version sets for inclusion in CI configuration

NSO in Docker encourages testing your repositories across multiple NSO versions, for example:

-   5.4.1 - the current version you use in production
-   5.4.5 - the latest maintenance release in the 5.4 train
    -   this is a smaller step than going to a newer release train, like 5.5
-   5.5.2 - the latest version of NSO, as the potential target to move to

Testing all your packages and code against multiple NSO versions makes it easier to move across NSO versions and reduces the risk of upgrade failures.

To simplify the management of this list of NSO versions, NSO in Docker makes use of a concept simply called `version sets`. A number of CI configuration snippets are generated from the version set definition and these CI snippets can be included in projects to always get an up to date list of NSO versions to built for.

The upstream home of the NSO in Docker repository at <https://gitlab.com/nso-developer/nso-docker/> will run with all currently supported versions of NSO. This is useful to ensure that nso-docker itself is compatible with a wide range of NSO versions but also as other repositories in the NSO in Docker ecosystem can be checked against the same range of versions. Its version set is defined in `version-sets/nso-developer/versions.json`. `version-sets/version-gen` is a Python script that is run from `version-sets/nso-developer/Makefile` and which uses `version-sets/nso-developer/versions.json` as input and produces a number of YAML files in `version-sets/nso-developer/` that can be included in the CI config of other repositories.

The repository skeletons default to including a version set that is relative to their own location.

    include:
      - project: '${CI_PROJECT_NAMESPACE}/nso-docker'
        ref: master
        file: '/version-sets/${CI_PROJECT_NAMESPACE}/build-tot5.yaml'

For example, the repository `https://gitlab.com/nso-developer/bgworker` will have its `${CI_PROJECT_NAMESPACE}` variable expanded to `nso-developer`, thus it will use the version-set defined in the upstream NSO in Docker repository that includes all supported versions of NSO. If you mirror it to your Gitlab instance, it will use the project namespace of your mirrored repository. For example, if you mirror it to `gitlab.example.com/acme/bgworker`, it will look for the version-set defined in the repository `gitlab.com/acme/nso-docker` at the path `version-sets/acme/build-tot5.yaml`.

You are expected to mirror this nso-docker repository to your own environment and create a version-set with the versions you are interested in.


## Create new version set

Merely copy an existing version set, modify the `versions.json` file and regenerate the files. For example;

    cp -av version-sets/nso-developer version-sets/acme
    cd version-sets/acme
    vi versions.json # edit the file to list the NSO versions you want
    make generate
    git add .
    git commit . -m "Add version-set for acme namespace"

Again, using the same name as your Gitlab project namespace means all skeleton repositories will automatically find the version-set.

It is possible to use any name you please for the version set, but then you will also need to modify all repositories that include the CI config snippets to use the correct path.


## Version set CI configuration snippets

If you have a large number of NSO versions defined but you want to test some packages against a smaller set of versions, you can achieve that by including different CI config snippets.

-   all the `build-*` files use a standard CI job definition called `build`
-   `build-all.yaml` all versions in the version set
-   `build-all4.yaml` only includes NSO 4.x versions
-   `build-all5.yaml` only includes NSO 5.x versions. Since NSO 5 looks quite different with schema-mount, it could be reasonable for some packages to only target NSO 5.
-   `build-tot.yaml` only includes the &ldquo;tip&rdquo; of each train, where a train is the combination of a major and minor version number. Patch releases are not considered for tip-of-train as they are not supposed to be used by the wide masses. For example, if we have 4.7, 4.7.1, 4.7.2 and 4.7.2.1 as well as 5.2.1, the tip-of-train would include 4.7.2 and 5.2.1.
    -   Similarly, there&rsquo;s also `build-tot4.yaml` and `build-tot5.yaml` for tip of train for NSO 4 or NSO 5 respectively.


# Continuous mirroring

You are encouraged to mirror any components in the NSO-in-Docker (NID) ecosystem that you use.

While you can rely on binaries built upstream, including them in your NSO system means a build time risk as broken Internet connectivity or similar could mean you cannot download the packages you depend on. If you need to quickly rebuild your system to integrate a small hot fix, such a risk could mean you cannot deploy a new version. Mirroring the git source repositories of your dependencies not only mean you get to build them locally but also allows you to make minor (or major) modifications to the source. It could be to update the `.gitlab-ci.yml` file to add a build for a different NSO version or a minor patch to a NED. Mirroring was kept in mind while designing NID ecosystem.

We think it is important to keep a copy of your dependencies locally (in your own Gitlab instance) such that you can build it yourself if necessary. We also think it is important to keep dependencies up to date - in fact, we would like to encourage to &ldquo;live-at-head&rdquo;, i.e. follow and include the latest version of a dependency. This is why continuous mirroring of an upstream repository makes sense. However, you should not blindly accept new versions into your main NSO system build as it can break your downstream builds. A gating function is needed and we propose a explicit version pinning workflow to provide for that gating function.

While NSO in Docker isn&rsquo;t specifically built for Gitlab (the intention is to make it more general than that), it is currently well suited to be hosted in Gitlab since the accompanying CI configuration file is for Gitlab CI. Gitlab features a mirroring functionality that can either push or pull in changes from a remote repository. For example, this functionality is used on this repository to keep it in sync (through pushing) with <https://github.com/nso-developer/nso-docker/>. You can use GitLab mirroring to continuously mirror this repository, however, it comes with a major constraint; only fast-forward merging is possible. This essentially prevents you from making even the most minute changes to the repository as continued mirroring will break. While you are encouraged to upstream any patches or changes you might have for this repository and others in the NID world, there are times when you want to make changes, for example if you need to apply a particular CI runner tag or limit the versions of NSO that you build for. To cater to such scenarios, an alternative mirror mechanism is provided: The CI configuration of this repository and the repo skeletons, are capable of mirroring itself from an upstream through a special CI job.

Enable mirroring from an upstream by scheduling a CI job and setting the `CI_MODE` variable to `mirror`. You create a CI schedule by going to `CI / CD` -> `Schedules` in Gitlab. In addition, you need to set a number of other variables for the mirroring functionality to work:

-   `CI_MODE`: `CI_MODE` must be set to `mirror` which will skip running any of the normal build and test jobs and instead only run the mirror job
-   `GITLAB_HOSTKEY`: the public hostkey(s) of the GitLab server
    -   run `ssh-keyscan URL-OF-YOUR-GITLAB-SERVER` to get suitable output to include in the variable value
-   `GIT_SSH_PRIV_KEY`: a private SSH key to use for cloning of its own repository and pushing the updates
    -   create a deploy key that has write privileges
        -   generate a key locally `ssh-keygen -t ed25519 -f my-nso-docker-mirror`
        -   in GitLab for your repository, go to `Settings` -> `CI / CD` -> `Deploy keys`
        -   create a new key, paste in the public part from what you generated
            -   Check `Write access allowed`
    -   enter the private key in the `GIT_SSH_PRIV_KEY` variable
-   `MIRROR_REMOTE`: the URL of the upstream repository that you wish to mirror
    -   for example, to mirror the authoritative repo for `nso-docker`, use `https://gitlab.com/nso-developer/nso-docker.git`
-   `MIRROR_PULL_MODE`: can be set to `rebase` to do `git pull --rebase` instead of a normal `git pull`

Set `CI_MODE=mirror` in the CI schedule (since this should only apply for that job and not the normal CI jobs). Use the repo wide CI variable section to set at least `GITLAB_HOSTKEY` and `GIT_SSH_PRIV_KEY`, possibly `MIRROR_REMOTE` too (or set from CI schedule). These are multi-line values and it appears some GitLab versions cannot correctly set multi-line values in the CI schedule, instead using repo wide CI variables effectively works around this issue.

The mirroring functionality is quite simple. It will run `git clone` to get a copy of its own repository (which is why it needs SSH host keys and deploy keys), then add the upstream repository as a HTTP mirror (presuming it is a public repository and does not require any credentials). It will then pull in changes, allowing merge conflicts, and finally push the result to its own repository, thus functionally achieving a mirror. It uses the user name and email of the user who initiated the CI build as the git commit author (for merge commits).


## Avoiding merge conflicts

A merge will be performed by the mirroring if necessary (when fast-forward isn&rsquo;t possible). As only automatic conflict resolution is possible, it is important to write changes in such a way that we reduce the likelihood of conflicts arising in the first place.

For example, it is often easier to make small adjustments to a file. If we want to modify the CI configuration we can place then bulk of our addition in a new file, for example `my-ci-config.yml` and include this from the `.gitlab-ci.yml` through an include statement, like so:

    include:
      - '/version-sets/supported-nso/nso-docker.yaml'
      - '/my-ci-config.yml'

Note how we are merely appending to the already existing include statement. It is a YAML dict and adding a new `include:` line would effectively overwrite the old one.


## Manually resolving merge conflicts

If you get a merge conflict, you will need to resolve it manually. Do this by cloning your repository, then adding the upstream repo as a git remote and pulling in from that:

    git clone git@example.com:my-group/nso-docker.git
    cd nso-docker
    git remote add upstream https://gitlab.com/nso-developer/nso-docker.git
    git pull upstream master

During the pull, if automatic merging is not possible, the merge will abort and give you the opportunity to sort out the conflicts. Do the needful and finally push back the result to your repo:

    git push origin master


# Contribution guidelines

Contributions are welcome, however before you start writing code, please open an issue to discuss your idea or bug fix to make sure your ideas or intended solution align with the goals or ideals of the project.

New functionality should be covered by new test cases that proves the new functionality works.


## Merge requests and CI

The typical workflow for submitting code involves forking this git repository, creating a branch and committing some code which will then be tested in CI. However, this project has a specialized CI runner that carries the NSO install files required to successfully build this project and this CI runner is only available for the origin repository, i.e. `gitlab.com/nso-developer/nso-docker`. A branch on your own private fork of this repository will not have access to the CI runner and thus will not be able to successfully execute the CI tests.

In order to run the tests, a maintainer will need to do a coarse review of the changes to verify there is no hostile code, after which your private branch can be copied to the `nso-developer/nso-docker` repository, which then allows it to be tested with the specialized CI runner. A shadow MR can then be setup to merge the commits to master. The commits still maintain the author, preserving credit for the changes.


# Mac OS X support

NSO in Docker generally works well on Mac OS X on x86<sub>64</sub> Intel CPUs. It runs on the Apple M1 too, although it is still too early to tell just how well.

Docker on Mac is using a Linux VM to run the Docker engine and as such, it is compatible with normal Docker images built for Linux. You don&rsquo;t need to recompile your NSO in Docker images when moving between a Linux machine Docker on Mac as they are both really running Docker on Linux.

NSO in Docker has been primarily developed on Linux. Continued development and testing happens on Linux first but the intention is to maintain OS X support.

What works:

-   building the NSO in Docker images `cisco-nso-base` and `cisco-nso-dev`
-   using the various NID skeletons to build packages and run test environments

What doesn&rsquo;t work:

-   running the test suite of nso-docker itself
    -   it relies on direct connectivity to the containers which isn&rsquo;t provided by Docker on Mac
    -   unless you are actually modifying this repo, you are unlikely to need to run the test suite

To build, make sure you have `realpath` installed, which comes with `coreutils` that you can install for example using `brew install coreutils`, in case you are using [brew](https://brew.sh/).

If you notice any issues, please open an issue.


# Windows support

Running NSO in Docker on Windows is supported, with some caveats. With a recent version of Windows 10 (May 2020 - version 2004), Docker is using a lightweight Linux VM using WSL2 (Windows Subsystem for Linux v2). As such, it is compatible with normal Docker images built for Linux. You don&rsquo;t need to recompile your NSO in Docker images when moving between a Linux machine and Docker in WSL2 as they are both really running Docker on Linux.

Prerequisites:

-   Windows 10, version 2004: <https://docs.microsoft.com/en-us/windows/whats-new/whats-new-windows-10-version-2004>
-   WSL2 installed: <https://docs.microsoft.com/en-us/windows/wsl/install-win10>
-   Windows Terminal is recommeneded: <https://www.microsoft.com/en-us/p/windows-terminal/9n0dx20hk701>

After installing the prerequisites, there are two methods of deploying Docker. Depending on the method, certain networking related aspects of NSO in Docker may not work:

1.  (Easy) Install Docker Desktop and enable WSL2 integration: <https://docs.docker.com/docker-for-windows/wsl/>. The Docker engine runs as a separate lightweight WSL2 VM, next to your preferred Linux distro. After enabling WSL2 integration with your preferred distro in Docker Desktop settings, docker commands are made available without requiring changes to your Linux distro. As a consequence of Docker running in a separate VM, direct network access to containers from Windows and Linux is not possible, only through port mapping: <https://docs.docker.com/docker-for-windows/networking>. Other features (volumes, isolated networks, &#x2026;) are not affected.
2.  (A bit more work) Install Docker engine directly in your preferred WSL2 distro: <https://docs.docker.com/engine/install/ubuntu/>. This method has feature parity with a &ldquo;bare&rdquo; Linux installation, so all aspects of NSO in Docker are expected to work. Since there is no systemd in WSL2, Docker engine must be started manually the first time WSL2 starts up.

Note that picking one of the methods does not prevent you from switching to the other (and back). If Docker Desktop is installed, enabling WSL2 distro integration will configure your distro at runtime to prefer the engine provided by Docker Desktop. This can be disabled, allowing your distro to revert to using its own Docker engine.

What works:

-   everything\* (except when using Docker Desktop, where there is no direct network access)

To build, you need `make` and Docker executable available in your preferred WSL2 distro. To test, there are some additional dependencies (same as Linux).

If you notice any issues, please open an issue.


# FAQ / Questions and answers


## Q: NSO consumes all / a lot of RAM, why?

Does `ulimit -n` report a limit of 1073741824 (~1 billion) open files? NSO uses that value to initialize some internal tables and 1 billion is too much. Lower the limit to something more reasonable, like a million open files. This seems to have popped up on some RedHat / Centos systems.

Check if it helps with `docker run --ulimit nofile=1048576 ...`

And set it permanently for your docker daemon through its configuration or how it is started on your system.


## Q: Why are these images not based on alpine or some other minimal container friendly image

**A**: The larger the final container image is, the less impact the base image size typically has. Picking a 5MB or 50MB base image is not crucial when the final image is an order of magnitude larger.

Debian was chosen as it is a well working proven distribution with a long track record. It is supported by a considerably sized community.

minideb, which is a minimal build of a debian base image, was not only considered but actually used in early phases of this repository. It does provide a smaller image. Measured at the time of the switch from minideb to stock debian, the difference was about 10%. minideb weighed in at 471MB while debian:buster came in at 525MB. The proven track record of Debian ultimately made it the winner.


## Q: Why use special entrypoints?

**A**: A delightful question with a less than delightful answer! It is a combination of multiple factors:

-   we want to be able to run
    -   `docker run -it cisco-nso-dev:5.3` to get interactive shell
    -   `docker run -it cisco-nso-dev:5.3 echo foo` to echo `foo` from within the container
    -   `docker run -it cisco-nso-dev:5.3 ncs_cli` to get the NSO CLI
-   `sh`, the Bourne shell, has a hard coded `PATH`
-   `ncs` is not installed in `PATH` of `sh`
-   we don&rsquo;t want to modify the NSO install
    -   likely error prone, in particular over time
-   we can modify `PATH` of `sh` by configuring our profile
-   `sh` only reads profile when started as interactive shell
-   Docker runs sh as non-interactive shell
    -   thus `sh` does not read profile

We solve this by effectively replacing Dockers standard use of `sh` by specifying our own entrypoint. It remains to be seen whether this is a good idea or a wildly bad one. Don&rsquo;t hesitate to open an issue in case you have an issue. It is however tested (see the `test-dev-entrypoint` test case) including some more exotic scenarios.

