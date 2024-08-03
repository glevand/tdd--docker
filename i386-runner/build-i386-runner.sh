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

export project_name='i386-runner'
export project_from='i386_debian'
export project_description='Builds a i386 Debian based Docker image with libstdc++5 support.'

VERSION=${VERSION:-"4"}

export extra_build_args='--platform=linux/386'

source ${DOCKER_TOP}/build-common.sh
