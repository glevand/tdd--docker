#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Runs a i386-runner container."
		echo "Usage: ${script_name} [flags] -- [command] [args]"
		echo "Option flags:"
		echo "  -n --container-name - Container name. Default: '${container_name}'."
		echo "  -a --docker-args    - Extra args for docker run. Default: '${docker_args}'"
		echo "  -t --docker-tag     - Docker tag. Default: '${docker_tag}'."
		echo "  -r --as-root        - Run as root user. Default: '${as_root}'."
		echo "  -h --help           - Show this help and exit."
		echo "  -v --verbose        - Verbose execution. Default: '${verbose}'."
		echo "  -g --debug          - Extra verbose execution. Default: '${debug}'."
		echo "Args:"
		echo "  command             - Default: '${user_cmd}'"
		echo "Info:"
		echo "  If no command is provided, runs an interactive container with"
		echo "  the current directory as the container's working directory."
		echo
		print_project_info
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts='n:a:t:rhvg'
	local long_opts='container-name:,docker-args:,docker-tag:,as-root,help,verbose,debug'

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

container_name='i386-runner'
docker_args=''
docker_tag='glevand/i386-runner:latest'
as_root=''
usage=''
verbose=''
debug=''

user_cmd='/bin/bash'
histfile="$(pwd)/${container_name}--bash_history"
run_check="${TDD_I386_RUNNER:-}"

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

tmp_dir="$(mktemp --tmpdir --directory "${script_name}.XXXX")"

if [[ ! ${SSH_AUTH_SOCK} ]]; then
	echo "${script_name}: ERROR: SSH_AUTH_SOCK not defined." >&2
fi

docker_extra_args='--platform=linux/386'

if ! echo "${docker_args}" | grep -q ' -w '; then
	docker_extra_args+=" -v '$(pwd)':'$(pwd)' -w '$(pwd)'"
fi

ansi_reset='\[\e[0m\]'
ansi_red='\[\e[1;31m\]'
ansi_green='\[\e[0;32m\]'
ansi_blue='\[\e[0;34m\]'
ansi_teal='\[\e[0;36m\]'

cp "${HOME}/.bashrc" "${tmp_dir}/"
echo "PS1='${ansi_green}\h@\${P_HOST}:${ansi_reset}\w\$ '" >> "${tmp_dir}/.bashrc"

if [[ ${as_root} ]]; then
	docker_user_args=''
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

docker_kvm_args=''
if [[ -c "/dev/kvm" ]]; then
	docker_kvm_args=" --device /dev/kvm --group-add $(stat --format=%g /dev/kvm)"
fi

eval "docker run \
	--rm \
	-it \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-v ${HOME}/.Xauthority:${HOME}/.Xauthority \
	-e DISPLAY \
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
	-e 'P_HOST=$(hostname)' \
	-v /etc/timezone:/etc/timezone:ro \
	-v /etc/localtime:/etc/localtime:ro \
	${docker_bash_args} \
	${docker_kvm_args} \
	${docker_user_args} \
	${docker_extra_args} \
	${docker_args} \
	${docker_tag} \
	${user_cmd}"

trap $'on_exit "Success"' EXIT
exit 0
