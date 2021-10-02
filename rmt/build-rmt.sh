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

project_name='rmt'
project_from='opensuse'
project_description='Builds a docker image that contains the SUSE RMT Repository Mirroring Tool server.'

VERSION=${VERSION:-"1"}
DOCKER_NAME=${DOCKER_NAME:-"rmt-server"}

curr_dir="$(pwd)"

build_on_exit() {
	true
}

docker_build_setup() {
	true
}

host_install_extra() {
	sudo cp -vf ${curr_dir}/rmt.conf /etc/rmt.conf
}

source ${DOCKER_TOP}/build-common.sh
