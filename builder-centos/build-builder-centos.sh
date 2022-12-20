#!/usr/bin/env bash

build_on_exit() {
	true
}

docker_build_setup() {
	true
}

host_install_extra() {
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

export project_name='tdd-builder-centos'
export project_from='centos'
export project_description='Builds a CentOS based docker image for compiling linux kernel, creating test rootfs, running QEMU.'

VERSION="${VERSION:-8.2}"

export extra_build_args=''

source ${DOCKER_TOP}/build-common.sh
