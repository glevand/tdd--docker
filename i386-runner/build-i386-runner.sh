#!/usr/bin/env bash
#
# (@PACKAGE_NAME@) version @PACKAGE_VERSION@
# @PACKAGE_URL@
# Send bug reports to: Geoff Levand <geoff@infradead.org>
#

export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"

DOCKER_TOP=${DOCKER_TOP:-"$(cd "${BASH_SOURCE%/*}/.." && pwd)"}

project_name="i386-runner"
project_from="i386_debian"
project_description="Builds a i386 Debian Buster based Docker image with libstdc++5 support."

PROJECT_TOP="${DOCKER_TOP}/${project_name}"
VERSION=${VERSION:-"1"}
DOCKER_NAME=${DOCKER_NAME:-"${project_name}"}

extra_build_args='--platform=linux/386'

build_on_exit() {
	true
}

docker_build_setup() {
	true
}

host_install_extra() {
	true
}

source "${DOCKER_TOP}/build-common.sh"
