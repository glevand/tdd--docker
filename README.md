# TDD docker

Docker container support for the
[TDD Project](https://github.com/glevand/tdd-project).

To ease deployment of the TDD framework Docker container images for the various
framework components are published to 
[Docker Hub](https://hub.docker.com/u/glevand/),
and systemd unit files are provided for those components that can be managed as
systemd services.

The
[docker-build-all.sh](https://github.com/glevand/tdd--docker/blob/master/docker-build-all.sh)
script will bulid all the TDD containers and can also install and enable the
systemd services of those containers that have them.  Individual containers and
services can be build and/or setup with the container's build script,
[build-jenkins.sh](https://github.com/glevand/tdd--docker/blob/master/jenkins/build-jenkins.sh)
for example.

## Licence & Usage

All files in the [TDD Project](https://github.com/glevand/tdd-project), unless
otherwise noted, are covered by an 
[MIT Plus License](https://github.com/glevand/tdd--docker/blob/master/mit-plus-license.txt).
The text of the license describes what usage is allowed.
