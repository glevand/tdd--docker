#!/usr/bin/env bash

usage () {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Runs a i386-runner container."
		echo "Usage: ${script_name} [flags] -- [command] [args]"
		echo "Option flags:"
		echo "  -a --docker-args    - Args for docker run. Default: '${docker_args}'"
		echo "  -n --container-name - Container name. Default: '${container_name}'."
		echo "  -t --docker-tag     - Docker tag. Default: '${docker_tag}'."
		echo "  -r --as-root        - Run as root user."
		echo "  -h --help           - Show this help and exit."
		echo "  -v --verbose        - Verbose execution."
		echo "  -g --debug          - Extra verbose execution."
		echo "Args:"
		echo "  command             - Default: '${user_cmd}'"
		echo "Notes:"
		echo "  If no <command> agrument is provided, runs an interactive container"
		echo "  with the current directory as the container's working directory."
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
	local short_opts="a:n:t:rhvg"
	local long_opts="docker-args:,container-name:,docker-tag:,as-root,help,verbose,debug"

	docker_args=''
	container_name=''
	docker_tag=''
	as_root=''
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
		-t | --docker-tag)
			docker_tag="${2}"
			shift 2
			;;
		-r | --as-root)
			as_root=1
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

real_source="$(realpath "${BASH_SOURCE}")"
SCRIPT_TOP="$(realpath "${SCRIPT_TOP:-${real_source%/*}}")"

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
docker_tag=${docker_tag:-"glevand/i386-runner:latest"}
histfile=${histfile:-"$(pwd)/${container_name}--bash_history"}
user_cmd=${user_cmd:-"/bin/bash"}

docker_extra_args='--platform=linux/386'

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

ansi_reset='\e[0m'
ansi_red='\e[1;31m'
ansi_green='\e[0;32m'
ansi_yellow='\e[1;33m'
ansi_blue='\e[0;34m'
ansi_teal='\e[0;36m'

cp "${HOME}/.bashrc" "${tmp_dir}/"
echo "PS1='${ansi_green}[\h@\${P_HOST}]:${ansi_reset}\w\$ '" >> "${tmp_dir}/.bashrc"

docker_user_args=''

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
if grep '127.0.0.53' /etc/resolv.conf >/dev/null; then
	docker_extra_args+=" --dns 127.0.0.53"
fi

if [[ ${verbose} ]]; then
	{
		echo "${script_name}: INFO: docker_tag = '${docker_tag}'"
		echo "${script_name}: INFO: docker_extra_args = '${docker_extra_args}'"
		echo ''
	} >&2
fi

#eval exec "docker run

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
	-e 'HISTFILE=${histfile}' \
	-e 'P_HOST=$(hostname)' \
	-v /etc/timezone:/etc/timezone:ro \
	-v /etc/localtime:/etc/localtime:ro \
	${docker_bash_args} \
	${docker_user_args} \
	${docker_extra_args} \
	${docker_args} \
	${docker_tag} \
	${user_cmd}"

trap - EXIT
on_exit 'Done, success.'
