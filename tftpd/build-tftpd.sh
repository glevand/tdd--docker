#!/usr/bin/env bash

if [[ ${JENKINS_URL:-} ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '
fi

set -e

script_name="${0##*/}"

DOCKER_TOP="${DOCKER_TOP:-$(realpath "${BASH_SOURCE%/*}/..")}"

project_name='tftpd'
project_from='alpine'
project_description='Builds a minimal docker image that contains tftpd-hpa.'

VERSION=${VERSION:-"1"}

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
