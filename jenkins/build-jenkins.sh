#!/usr/bin/env bash

if [[ ${JENKINS_URL:-} ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '
fi

set -e

script_name="${0##*/}"

real_source="$(realpath "${BASH_SOURCE}")"
DOCKER_TOP="$(realpath "${DOCKER_TOP:-${real_source%/*}/..}")"

project_name='jenkins'
project_from='openjdk'
project_description='Builds a docker image that contains Jenkins for the TDD Project.'

VERSION=${VERSION:-"1"}
JENKINS_USER=${JENKINS_USER:-'tdd-jenkins'}

if ! getent passwd ${JENKINS_USER} &> /dev/null; then
	echo "${script_name}: WARNING: User '${JENKINS_USER}' not found." >&2
	echo "${script_name}: WARNING: Run useradd-jenkins.sh to add." >&2
fi

extra_build_args="\
	--build-arg user=$(id --user --real --name ${JENKINS_USER}) \
	--build-arg uid=$(id --user --real ${JENKINS_USER}) \
	--build-arg group=$(id --group --real --name ${JENKINS_USER}) \
	--build-arg gid=$(id --group --real ${JENKINS_USER}) \
	--build-arg host_docker_gid=$(stat --format=%g /var/run/docker.sock) \
"

build_on_exit() {
	true
}

docker_build_setup() {
	true
}

host_install_extra() {
	true
}

source ${DOCKER_TOP}/build-common.sh
