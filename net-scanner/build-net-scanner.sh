#!/usr/bin/env bash

if [[ ${JENKINS_URL:-} ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '
fi

set -e

script_name="${0##*/}"

real_source="$(realpath "${BASH_SOURCE}")"
DOCKER_TOP="$(realpath "${DOCKER_TOP:-${real_source%/*}/..}")"

project_name='net-scanner'
project_from='debian'
project_description='Builds a docker image that contains tools for gathering information about a network.'

VERSION="${VERSION:-2}"

docker_build_setup() {
	echo "${script_name}: Building unicornscan." >&2

	rm -rf "${PROJECT_TOP}/u-install"

	local builder_tag="$("${DOCKER_TOP}/builder/build-builder.sh" --tag)"

		cat << EOF > "${tmp_dir}/build.sh"
export PS4='\[\e[0;32m\]+ tdd-build-script:\${LINENO}:\[\e[0m\] '
set -x

top_dir="/work"

rm -rf "\${top_dir}/u-build" "\${top_dir}/u-install"
mkdir -p "\${top_dir}/u-build"

pushd "\${top_dir}/u-build"
curl --location --output unicornscan-0.4.7-2.tar.bz2 https://sourceforge.net/projects/osace/files/unicornscan/unicornscan%20-%200.4.7%20source/unicornscan-0.4.7-2.tar.bz2
tar -xf unicornscan-0.4.7-2.tar.bz2
ls -l ./unicornscan-0.4.7
pushd ./unicornscan-0.4.7

sed --in-place 's/inline tsc_t get_tsc/tsc_t get_tsc/g' src/unilib/tsc.c

./configure CFLAGS='-D_GNU_SOURCE' -prefix=/
make
mkdir -p "\${top_dir}/u-install"
make DESTDIR="\${top_dir}/u-install" install

popd
file "\${top_dir}/u-install/bin/unicornscan"
EOF

	docker run --rm \
		--network=host \
		-v ${tmp_dir}:/work -w /work \
		-u $(id --user --real):$(id --group --real) \
		${builder_tag} bash -ex ./build.sh

	cp -av "${tmp_dir}/u-install" "${PROJECT_TOP}/"
}

host_install_extra() {
	true
}

build_on_exit() {
	rm -rf "${PROJECT_TOP}/u-install"
}

source "${DOCKER_TOP}/build-common.sh"
