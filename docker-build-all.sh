#!/usr/bin/env bash

usage() {
	local old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	{
		echo "${script_name} - Builds all TDD container images."
		echo "Usage: ${script_name} [flags]"
		echo "Option flags:"
		echo "  -i --info     - Show project help."
		echo "  -p --purge    - Remove existing docker image and rebuild."
		echo "  -r --rebuild  - Rebuild existing docker image."
		echo "  --install     - Install systemd service files."
		echo "  --start       - Start systemd services."
		echo "  --enable      - Enable systemd services."
		echo "  -h --help     - Show this help and exit."
		echo "  -v --verbose  - Verbose execution. Default: '${verbose}'."
		echo "  -g --debug    - Extra verbose execution. Default: '${debug}'."
		echo "Info:"
		echo "  ${PACKAGE_NAME} ${script_name}"
		echo "  Version: ${PACKAGE_VERSION}"
		echo "  Project Home: ${PACKAGE_URL}"
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="iprhvg"
	local long_opts="info,purge,rebuild,install,start,enable,help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-i | --info)
			info=1
			shift
			;;
		-p | --purge)
			purge=1
			shift
			;;
		-r | --rebuild)
			rebuild=1
			shift
			;;
		--install)
			install=1
			shift
			;;
		--start)
			start=1
			shift
			;;
		--enable)
			enable=1
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
			keep_tmp_dir=1
			set -x
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

	set +x
	echo "${script_name}: Done: ${result}, ${sec} sec." >&2
}

on_err() {
	local f_name=${1}
	local line_no=${2}
	local err_no=${3}

	{
		if [[ ${debug:-} ]]; then
			echo '------------------------'
			set
			echo '------------------------'
		fi

		echo "${script_name}: ERROR: function=${f_name}, line=${line_no}, result=${err_no}"
	} >&2

	exit "${err_no}"
}

get_arch() {
	local a=${1}

	case "${a}" in
	arm64|aarch64) echo "arm64" ;;
	amd64|x86_64)  echo "amd64" ;;
	*)
		echo "${script_name}: ERROR: Bad arch '${a}'" >&2
		exit 1
		;;
	esac
}

#===============================================================================
if [[ ${JENKINS_URL:-} ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '
fi

script_name="${0##*/}"

SECONDS=0
start_time="$(date +%Y.%m.%d-%H.%M.%S)"

DOCKER_TOP="${DOCKER_TOP:-$(realpath "${BASH_SOURCE%/*}")}"

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR
trap 'on_err SIGUSR1 ? 3' SIGUSR1

set -eE
set -o pipefail
set -o nounset

info=''
purge=''
rebuild=''
install=''
start=''
enable=''
usage=''
verbose=''
debug=''

PACKAGE_NAME='TDD'
PACKAGE_VERSION="$(${DOCKER_TOP}/version.sh)"
PACKAGE_URL='http://github.com/glevand/tdd--docker'

process_opts "${@}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

echo "${script_name} (${PACKAGE_NAME}) version ${PACKAGE_VERSION}" >&2

if [[ ${extra_args} ]]; then
	set +o xtrace
	echo "${script_name}: ERROR: Got extra args: '${extra_args}'" >&2
	usage
	exit 1
fi

host_arch=$(get_arch "$(uname -m)")

case ${host_arch} in
amd64|arm64)
	projects='
		builder
		builder-centos
		relay
		jenkins
		tftpd
	'
	;;
*)
	echo "${script_name}: ERROR: Unknown host: '${host_arch}'" >&2
	exit 1
	;;
esac

extra_args=''

if [[ ${info} ]]; then
	extra_args+='--help '
else
	set -x
	extra_args+='--verbose '
fi

if [[ ${purge} ]]; then
	extra_args+='--purge '
elif [[ ${rebuild} ]]; then
	extra_args+='--rebuild '
fi

if [[ ${install} ]]; then
	extra_args+='--install '
fi
if [[ ${start} ]]; then
	extra_args+='--start '
fi
if [[ ${enable} ]]; then
	extra_args+='--enable '
fi


for p in ${projects}; do
	"${DOCKER_TOP}/${p}/build-${p}.sh" ${extra_args}
	echo '===================================' >&2
done

trap "on_exit 'Success'" EXIT
exit 0
