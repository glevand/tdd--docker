#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Enter a running tdd-net-scanner container."
		echo "Usage: ${script_name} [flags] -- [command] [args]"
		echo "Option flags:"
		echo "  -n --container-name - Container name. Default: '${container_name}'."
		echo "  -a --docker-args    - Extra args for docker exec. Default: '${docker_args}'"
		echo "  -p --as-privileged  - Run command as privileged. Default: '${as_privileged}'."
		echo "  -h --help           - Show this help and exit."
		echo "  -v --verbose        - Verbose execution. Default: '${verbose}'."
		echo "  -g --debug          - Extra verbose execution. Default: '${debug}'."
		echo "Args:"
		echo "  command             - Default: '${user_cmd}'"
		echo "Info:"
		print_project_info
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts='n:a:phvg'
	local long_opts='container-name:,docker-args:,as-privileged,help,verbose,debug'

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-n | --container-name)
			container_name="${2}"
			shift 2
			;;
		-a | --docker-args)
			docker_args="${2}"
			shift 2
			;;
		-p | --as-privileged)
			as_privileged=1
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
			verbose=1
			debug=1
			set -x
			shift
			;;
		--)
			shift
			if [[ ${1:-} ]]; then
				user_cmd="${*}"
			fi
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

print_project_banner() {
	echo "${script_name} (@PACKAGE_NAME@) - ${start_time}"
}

print_project_info() {
	echo "  @PACKAGE_NAME@ ${script_name}"
	echo "  Version: @PACKAGE_VERSION@"
	echo "  Project Home: @PACKAGE_URL@"
}

on_exit() {
	local result=${1}

	local sec="${SECONDS}"

	set +x
	echo "${script_name}: Done: ${result}, ${sec} sec." >&2
}

on_err() {
	local f_name=${1}
	local line_no=${2}
	local err_no=${3}

	echo "${script_name}: ERROR: function=${f_name}, line=${line_no}, result=${err_no}"
	exit "${err_no}"
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"

SECONDS=0
start_time="$(date +%Y.%m.%d-%H.%M.%S)"

real_source="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_TOP="$(realpath "${SCRIPT_TOP:-${real_source%/*}}")"

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR
trap 'on_err SIGUSR1 ? 3' SIGUSR1

set -eE
set -o pipefail
set -o nounset

container_name='tdd-net-scanner'
docker_args=''
as_privileged=''
usage=''
verbose=''
debug=''
user_cmd='/bin/bash'

run_check="${TDD_NET_SCANNER:-}"

process_opts "${@}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

print_project_banner >&2

if [ ${run_check} ]; then
	echo "${script_name}: ERROR: Already in ${container_name}." >&2
	exit 1
fi

if [[ ${as_privileged} ]]; then
	docker_extra_args=' --privileged'
else
	docker_extra_args=''
fi

eval "docker exec -it ${docker_args} ${docker_extra_args} ${container_name} ${user_cmd}"

trap $'on_exit "Success"' EXIT
exit 0
