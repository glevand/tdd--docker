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

export project_name='builder-focal'
export project_from='ubuntu_focal'
export project_description='An Ubuntu 20.04 Focal based builder.'

VERSION=${VERSION:-"1"}

export extra_build_args=''

source ${DOCKER_TOP}/build-common.sh
