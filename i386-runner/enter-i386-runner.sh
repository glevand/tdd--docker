#!/usr/bin/env bash

usage () {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Enter a running i386-runner container."
		echo "Usage: ${script_name} [flags] -- [command] [args]"
		echo "Option flags:"
		echo "  -a --docker-args    - Args for docker exec. Default: '${docker_args}'"
		echo "  -n --container-name - Container name. Default: '${container_name}'."
		echo "  -p --as-privileged  - Run command as privileged."
		echo "  -h --help           - Show this help and exit."
		echo "  -v --verbose        - Verbose execution."
		echo "  -g --debug          - Extra verbose execution."
		echo "Args:"
		echo "  command             - Default: '${user_cmd}'"
	} >&2

	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="a:n:phvg"
	local long_opts="container-name:,as-privileged,help,verbose,debug"

	docker_args=''
	container_name=''
	as_privileged=''
	usage=''
	verbose=''
	debug=''

	local opts
	if ! opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@"); then
		echo "${script_name}: ERROR: Internal getopt" >&2
		exit 1
	fi

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-a | --docker-args)
			docker_args="${2}"
			shift 2
			;;
		-n | --container-name)
			container_name="${2}"
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
			set -x
			verbose=1
			debug=1
			shift
			;;
		--)
			shift
			user_cmd="${*}"
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

	if [[ -d "${tmp_dir:-}" ]]; then
		rm -rf "${tmp_dir:?}"
	fi

	echo "${script_name}: ${result}" >&2
}

on_err() {
	local f_name=${1}
	local line_no=${2}
	local err_no=${3}

	echo "${script_name}: ERROR: function=${f_name}, line=${line_no}, result=${err_no}" >&2
	exit "${err_no}"
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"
SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd )"}

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR
trap 'on_err SIGUSR1 ? 3' SIGUSR1

set -eE
set -o pipefail
set -o nounset

if [ "${TDD_I386_RUNNER-}" ]; then
	echo "${script_name}: ERROR: Already in i386-runner." >&2
	exit 1
fi

process_opts "${@}"

container_name=${container_name:-"i386-runner"}
user_cmd=${user_cmd:-"/bin/bash"}

docker_extra_args=''

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

if [[ ${as_privileged} ]]; then
	docker_extra_args+=" --privileged"
fi

eval "docker exec \
	-it \
	${docker_extra_args} \
	${docker_args} \
	${container_name} \
	${user_cmd}"

trap - EXIT
on_exit 'Done, success.'
