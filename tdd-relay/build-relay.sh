#!/usr/bin/env bash

docker_build_setup() {
	local relay_src="$(realpath "${PROJECT_TOP}/../../relay")"

	echo "${script_name}: Building tdd-relay image." >&2

	cp -a "${relay_src}" "${tmp_dir}/relay-build"

	cat << EOF > "${tmp_dir}/build.sh"
#!/usr/bin/env bash

export PS4='\[\e[0;32m\]+ tdd-build-script:\${LINENO}:\[\e[0m\] '
set -x

cd '/work/relay-build'
./bootstrap
./configure --enable-debug
make
EOF

	chmod 777 "${tmp_dir}/build.sh"

	docker run --rm \
		--user "$(id --user --real):$(id --group --real)" \
		--volume ${tmp_dir}:/work \
		--workdir /work \
		--network=host \
		glevand/tdd-builder:latest '/work/build.sh'

	file "${tmp_dir}/relay-build/tdd-relay"
	cp -av "${tmp_dir}/relay-build/tdd-relay" "${PROJECT_TOP}/"
}

host_install_extra() {
	local relay_src="$(realpath "${PROJECT_TOP}/../../relay")"

	sudo cp -vf "${relay_src}/tdd-relay.conf.sample" "/etc/tdd-relay.conf"
}

build_on_exit() {
	rm -rf "${PROJECT_TOP}/tdd-relay"
}

#===============================================================================
if [[ ${JENKINS_URL} ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '
fi

script_name="${0##*/}"

real_source="$(realpath "${BASH_SOURCE[0]}")"
DOCKER_TOP="$(realpath "${DOCKER_TOP:-${real_source%/*}/..}")"

export project_name='tdd-relay'
export project_from='debian'
export project_description='Builds a docker image that contains the TDD relay service.'

VERSION="${VERSION:-4}"

export extra_build_args=''

source "${DOCKER_TOP}/build-common.sh"
