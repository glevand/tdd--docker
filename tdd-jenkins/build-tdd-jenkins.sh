#!/usr/bin/env bash

docker_build_setup() {
	true
}

host_install_extra() {
	true
}

build_on_exit() {
	true
}

#===============================================================================
if [[ ${JENKINS_URL} ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '
fi

script_name="${0##*/}"

real_source="$(realpath "${BASH_SOURCE[0]}")"
DOCKER_TOP="$(realpath "${DOCKER_TOP:-${real_source%/*}/..}")"

export project_name='tdd-jenkins'
export project_from='jenkins'
export project_description='Builds a Jenkins docker image for the TDD Project.'

VERSION="${VERSION:-2}"

JENKINS_USER="${JENKINS_USER:-jenkins}"
JENKINS_PASSWD="${JENKINS_PASSWD:-jenkins}"
JENKINS_GROUP="${JENKINS_GROUP:-jenkins}"
JENKINS_UID="${JENKINS_UID:-1000}"
JENKINS_GID="${JENKINS_GID:-1000}"
JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}"

export extra_build_args="\
	--build-arg JENKINS_USER=${JENKINS_USER} \
	--build-arg JENKINS_PASSWD=${JENKINS_PASSWD} \
	--build-arg JENKINS_GROUP=${JENKINS_GROUP} \
	--build-arg JENKINS_UID=${JENKINS_UID} \
	--build-arg JENKINS_GID=${JENKINS_GID} \
	--build-arg JENKINS_HOME=${JENKINS_HOME} \
	--build-arg host_docker_gid=$(stat --format=%g /var/run/docker.sock) \
"

# shellcheck source=docker/build-common.sh
source "${DOCKER_TOP}/build-common.sh"
