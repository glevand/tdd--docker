#!/usr/bin/env bash

build_on_exit() {
	true
}

docker_build_setup() {
	true
}

host_install_extra() {
	sudo cp -vf ${curr_dir}/rmt.conf /etc/rmt.conf
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

export project_name='tdd-rmt'
export project_from='opensuse'
export project_description='Builds a docker image that contains the SUSE RMT Repository Mirroring Tool server.'

VERSION="${VERSION:-2}"

DOCKER_NAME=${DOCKER_NAME:-"rmt-server"}

curr_dir="$(pwd)"

export extra_build_args=''

source ${DOCKER_TOP}/build-common.sh
