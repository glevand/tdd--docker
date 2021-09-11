#!/usr/bin/env bash

usage () {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	{
		echo "${script_name} - Runs a TDD net-scanner container.  If no command is provided, runs an interactive container with the current directory as the container's working directory."
		echo "Usage: ${script_name} [flags] -- [command] [args]"
		echo "Option flags:"
		echo "  -a --docker-args    - Args for docker run. Default: '${docker_args}'"
		echo "  -n --container-name - Container name. Default: '${container_name}'."
		echo "  -t --docker-tag     - Docker tag. Default: '${docker_tag}'."
		echo "  -r --as-root        - Run as root user."
		echo "  -h --help           - Show this help and exit."
		echo "  -v --verbose        - Verbose execution. Default: '${verbose}'."
		echo "  -g --debug          - Extra verbose execution. Default: '${debug}'."
		echo "Args:"
		echo "  command             - Default: '${user_cmd}'"
		echo "Examples:"
		echo "  ${script_name} -v"
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="a:n:t:rhvg"
	local long_opts="docker-args:,container-name:,docker-tag:,as-root,help,verbose,debug"

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
		-t | --docker-tag)
			docker_tag="${2}"
			shift 2
			;;
		-r | --as-root)
			as_root=1
			shift
			;;
...		-h | --help)
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
			keep_tmp_dir=1
			set -x
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

	if [ -d "${tmp_dir}" ]; then
		rm -rf "${tmp_dir}"
	fi

	echo "${script_name}: ${result}" >&2
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"

if [ "${TDD_NET_SCANNER}" ]; then
	echo "${script_name}: ERROR: Already in tdd-net-scanner." >&2
	exit 1
fi

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd )"}

trap "on_exit 'Done, failed.'" EXIT
set -e

process_opts "${@}"

container_name=${container_name:-"tdd-net-scanner"}
docker_tag=${docker_tag:-"tdd-net-scanner:latest"}
histfile=${histfile:-"$(pwd)/${container_name}--bash_history"}
user_cmd=${user_cmd:-"/bin/bash"}

unset docker_extra_args

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

tmp_dir="$(mktemp --tmpdir --directory "${script_name}.XXXX")"

if [[ ! ${SSH_AUTH_SOCK} ]]; then
	echo "${script_name}: ERROR: SSH_AUTH_SOCK not defined." >&2
fi

if ! echo "${docker_args}" | grep -q ' -w '; then
	docker_extra_args+=" -v '$(pwd)':'$(pwd)' -w '$(pwd)'"
fi

ansi_reset='\[\e[0m\]'
ansi_red='\[\e[1;31m\]'
ansi_green='\[\e[0;32m\]'
ansi_blue='\[\e[0;34m\]'
ansi_teal='\[\e[0;36m\]'

cp "${HOME}/.bashrc" "${tmp_dir}/"
echo "PS1='${ansi_green}\u@\h:${ansi_reset}\w\$ '" > "${tmp_dir}/.bashrc"

unset docker_user_args
if [[ ${as_root} ]]; then
	docker_bash_args=" -v ${tmp_dir}/.bashrc:/root/.bashrc"
else
	docker_user_args=" \
	-u $(id --user --real):$(id --group --real) \
	-v ${HOME}/.ssh:${HOME}/.ssh:ro \
	-v /etc/group:/etc/group:ro \
	-v /etc/passwd:/etc/passwd:ro \
	-v /etc/shadow:/etc/shadow:ro \
	"
	docker_bash_args=" -v ${tmp_dir}/.bashrc:${HOME}/.bashrc"
fi

# Use the host's systemd-resolved to get /etc/hosts.
if grep -E '127.0.0.53' /etc/resolv.conf; then
	docker_extra_args+=" --dns 127.0.0.53"
fi

echo "${script_name}: INFO: docker_extra_args = '${docker_extra_args}'" >&2

eval "docker run \
	--rm \
	-it \
	-e USER \
	-v /dev:/dev \
	--privileged \
	--network host \
	--name ${container_name} \
	--hostname ${container_name} \
	--add-host ${container_name}:127.0.0.1 \
	-v ${SSH_AUTH_SOCK}:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent \
	--group-add $(stat --format=%g /var/run/docker.sock) \
	--group-add sudo \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /dev:/dev \
	-e 'TERM=xterm-256color' \
	-e 'HISTFILE=${histfile}' \
	${docker_bash_args} \
	${docker_user_args} \
	${docker_extra_args} \
	${docker_args} \
	${docker_tag} \
	${user_cmd}"

trap - EXIT
on_exit 'Done, success.'
