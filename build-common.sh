#!/usr/bin/env bash

usage () {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - ${project_description}"
		echo "Usage: ${script_name} [flags]"
		echo "Option flags:"
		echo "  -p --purge    - Remove existing docker image and rebuild."
		echo "  -r --rebuild  - Rebuild existing docker image."
		echo "  -t --tag      - Print Docker tag to stdout and exit."
		echo "  -h --help     - Show this help and exit."
		echo "  -v --verbose  - Verbose execution."
		echo "  -g --debug    - Extra verbose execution."
		echo "Systemd setup:"
		echo "  --install     - Install systemd service files."
		echo "  --start       - Start systemd services."
		echo "  --enable      - Enable systemd services."
		echo "Environment:"
		echo "  DOCKER_FILE   - Default: '${DOCKER_FILE}'"
		echo "  DOCKER_FROM   - Default: '${DOCKER_FROM}'"
		echo "  DOCKER_TAG    - Default: '${DOCKER_TAG}'"
		if [[ ${JENKINS_USER-} ]];then
			echo "  JENKINS_USER  - Default: '${JENKINS_USER}'"
		fi
		echo "Examples:"
		echo "  ${script_name} -v"
		echo "Info:"
		echo "  ${script_name} (@PACKAGE_NAME@) version @PACKAGE_VERSION@"
		echo "  @PACKAGE_URL@"
		echo "  Send bug reports to: Geoff Levand <geoff@infradead.org>."
	} >&2

	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="prthvg"
	local long_opts="purge,rebuild,tag,help,verbose,debug,install,start,enable"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		case "${1}" in
		-p | --purge)
			purge=1
			shift
			;;
		-r | --rebuild)
			rebuild=1
			shift
			;;
		-t | --tag)
			tag=1
			shift
			;;
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			verbose=1
			shift
			;;
		-g | --debug)
			set -x
			verbose=1
			debug=1
			shift
			;;
		--install)
			install=1
			shift
			;;
		--start)
			install=1
			start=1
			shift
			;;
		--enable)
			install=1
			enable=1
			shift
			;;
		--)
			shift
			extra_args="${*}"
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${1}
	local sec="${SECONDS}"

	if [[ -d "${tmp_dir:-}" ]]; then
		if [[ ${keep_tmp_dir:-} ]]; then
			echo "${script_name}: INFO: tmp dir preserved: '${tmp_dir}'" >&2
		else
			rm -rf "${tmp_dir:?}"
		fi
	fi

	build_on_exit "${result}"
	set +x
	echo "${script_name}: Done: ${result}, ${sec} sec." >&2
}

on_err() {
	local f_name=${1}
	local line_no=${2}
	local err_no=${3}

	echo "${script_name}: ERROR: function=${f_name}, line=${line_no}, result=${err_no}" >&2
	exit "${err_no}"
}

version () {
	echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

get_arch() {
	local arch
	arch="${1:-$(uname -m)}"

	case "${arch}" in
	arm64|aarch64)
		echo "arm64"
		;;
	amd64|x86_64)
		echo "amd64"
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

arch_tag() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	*)
		echo "-${arch}"
		;;
	esac
}

docker_from_alpine() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	amd64)
		DOCKER_FROM="${DOCKER_FROM:-alpine:latest}"
		;;
	arm64)
		DOCKER_FROM="${DOCKER_FROM:-arm64v8/alpine:latest}"
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

docker_from_centos() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	amd64)
		DOCKER_FROM="${DOCKER_FROM:-centos:8}"
		;;
	arm64)
		DOCKER_FROM="${DOCKER_FROM:-centos:8}"
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

docker_from_debian() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	amd64)
		DOCKER_FROM="${DOCKER_FROM:-debian:buster}"
		;;
	arm64)
		DOCKER_FROM="${DOCKER_FROM:-arm64v8/debian:buster}"
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

docker_from_debian_jessie() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	amd64)
		DOCKER_FROM="${DOCKER_FROM:-debian:jessie}"
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

docker_from_i386_debian() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	amd64)
		DOCKER_FROM="${DOCKER_FROM:-i386/debian:buster}"
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

docker_from_jenkins() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	amd64)
		DOCKER_FROM="${DOCKER_FROM:-jenkins/jenkins:lts}"
		;;
	arm64)
		echo "arm64 not available"
		exit 1
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

docker_from_openjdk() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	amd64)
		DOCKER_FROM="${DOCKER_FROM:-openjdk:8-jdk}"
		;;
	arm64)
		DOCKER_FROM="${DOCKER_FROM:-arm64v8/openjdk:8-jdk}"
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

docker_from_opensuse() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	amd64)
		DOCKER_FROM="${DOCKER_FROM:-opensuse/leap:15.1}"
		;;
	arm64)
		DOCKER_FROM="${DOCKER_FROM:-arm64v8/opensuse/leap:15.1}"
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

docker_from_ubuntu() {
	local arch
	arch="$(get_arch "$(uname -m)")"

	case "${arch}" in
	amd64)
		DOCKER_FROM="${DOCKER_FROM:-ubuntu:18.04}"
		;;
	arm64)
		DOCKER_FROM="${DOCKER_FROM:-arm64v8/ubuntu:18.04}"
		;;
	*)
		echo "${script_name}: ERROR: Unknown arch '${arch}'" >&2
		exit 1
		;;
	esac
}

set_docker_from() {
	local from=${1}

	case "${from}" in
	alpine)
		docker_from_alpine
		;;
	centos)
		docker_from_centos
		;;
	debian)
		docker_from_debian
		;;
	debian_jessie)
		docker_from_debian_jessie
		;;
	i386_debian)
		docker_from_i386_debian
		;;
	jenkins)
		docker_from_jenkins
		;;
	openjdk)
		docker_from_openjdk
		;;
	opensuse)
		docker_from_opensuse
		;;
	ubuntu)
		docker_from_ubuntu
		;;
	*)
		echo "${script_name}: ERROR: Bad project_from: '${from}'" >&2
		exit 1
	esac
}

show_tag () {
	echo "${DOCKER_TAG}"
}

#===============================================================================
if [[ ${JENKINS_URL} ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '
fi

SECONDS=0
# start_time="$(date +%Y.%m.%d-%H.%M.%S)"

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR
trap 'on_err SIGUSR1 ? 3' SIGUSR1

set -eE
set -o pipefail
set -o nounset

if [[ ${TDD_BUILDER-} && "${project_name}" == "builder"  ]]; then
	echo "${script_name}: ERROR: Building builder in builder not supported." >&2
	exit 1
fi

PROJECT_TOP="${DOCKER_TOP}/${project_name}"
ARCH_TAG="${ARCH_TAG:-$(arch_tag)}"
DOCKER_TAG="${DOCKER_TAG:-${DOCKER_NAME}:${VERSION}${ARCH_TAG}}"

DOCKER_FILE="${DOCKER_FILE:-${PROJECT_TOP}/Dockerfile.${project_name}}"
SERVICE_FILE="${SERVICE_FILE:-${PROJECT_TOP}/tdd-${project_name}.service}"

purge=''
rebuild=''
tag=''
usage=''
verbose=''
debug=''
install=''
start=''
enable=''
extra_build_args=''


process_opts "${@}"

set_docker_from "${project_from}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

if ! test -x "$(command -v docker)"; then
	echo "${script_name}: ERROR: Please install docker." >&2
	exit 1
fi

if [[ ${tag} ]]; then
	show_tag
	trap - EXIT
	exit 0
fi

tmp_dir="$(mktemp --directory --tmpdir "tdd-${script_name}-XXXX")"

# Support for docker versions older than 17.05.
# See https://github.com/moby/moby/issues/32457
if [[ $(version "$(docker version --format '{{.Server.Version}}')") < $(version "17.05") ]]; then
	tmp_file="${DOCKER_FILE}.tmp"
	trap "rm -f ${tmp_file}" EXIT

	cp -f "${DOCKER_FILE}" "${tmp_file}"
	DOCKER_FILE="${tmp_file}"
	sed --in-place "s|ARG DOCKER_FROM||" "${tmp_file}"
	sed --in-place "s|\${DOCKER_FROM}|${DOCKER_FROM}|" "${tmp_file}"
fi

do_build=1

if [[ ${purge} ]] && docker inspect --type image "${DOCKER_TAG}" &>/dev/null; then
	echo "Removing docker image: ${DOCKER_TAG}" >&2
	docker rmi --force "${DOCKER_TAG}"
elif [[ ! ${rebuild} ]] && docker inspect --type image "${DOCKER_TAG}" &>/dev/null; then
	echo "Docker image exists: ${DOCKER_TAG}" >&2
	do_build=
fi

cd "${PROJECT_TOP}"

if [[ ${do_build} ]]; then
	echo "${script_name}: Building docker image: ${DOCKER_TAG}" >&2

	docker pull "${DOCKER_FROM}"

	docker_build_setup

	echo "${script_name}: extra_build_args='${extra_build_args}'" >&2

	docker build \
		--file "${DOCKER_FILE}" \
		--build-arg DOCKER_FROM="${DOCKER_FROM}" \
		--tag "${DOCKER_TAG}" \
		--network=host \
		${extra_build_args:+${extra_build_args}} \
		.
fi

if [[ ${install} ]]; then
	host_install_extra
fi

if [[ -f ${SERVICE_FILE} ]]; then
	service_name="${SERVICE_FILE##*/}"
	
	if [[ ${install} ]]; then
		tmp_file="${tmp_dir}/${service_name}"

		cp -f "${SERVICE_FILE}" "${tmp_file}"
		sed --in-place "s/@@docker-tag@@/${DOCKER_TAG}/g" "${tmp_file}"
		sudo cp -f "${tmp_file}" "/etc/systemd/system/"
	fi

	if [[ ${enable} ]]; then
		sudo systemctl reenable "${service_name}"
	fi

	if [[ ${start} ]]; then
		sudo systemctl daemon-reload
		sudo systemctl restart "${service_name}"
		docker ps
		systemctl --no-pager status "${service_name}"
	fi
fi

show_tag

trap "on_exit 'Success.'" EXIT
exit 0
