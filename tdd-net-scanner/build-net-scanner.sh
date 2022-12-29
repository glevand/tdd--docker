#!/usr/bin/env bash

docker_build_setup() {
	echo "${script_name}: Building unicornscan." >&2

	local tmp_dir='/tmp/net-scanner'

	rm -rf "${tmp_dir}"
	mkdir -p "${tmp_dir}"

	cat << EOF > "${tmp_dir}/build.sh"
#!/usr/bin/env bash

export PS4='\[\e[0;32m\]+ tdd-build-script:\${LINENO}:\[\e[0m\] '
set -x

work_dir='/work'

rm -rf "\${work_dir}/u-build" "\${work_dir}/u-install"
mkdir -p "\${work_dir}/u-build"

pushd "\${work_dir}/u-build"
curl --location --output unicornscan-0.4.7-2.tar.bz2 https://sourceforge.net/projects/osace/files/unicornscan/unicornscan%20-%200.4.7%20source/unicornscan-0.4.7-2.tar.bz2
tar -xf unicornscan-0.4.7-2.tar.bz2

cd ./unicornscan-0.4.7
sed --in-place 's/inline tsc_t get_tsc/tsc_t get_tsc/g' src/unilib/tsc.c

./configure CFLAGS='-D_GNU_SOURCE' -prefix=/
make
mkdir -p "\${work_dir}/u-install"
make DESTDIR="\${work_dir}/u-install" install

popd
file "\${work_dir}/u-install/bin/unicornscan"
EOF

	chmod 777 "${tmp_dir}/build.sh"

	docker run --rm \
		--user "$(id --user --real):$(id --group --real)" \
		--volume ${tmp_dir}:/work \
		--workdir /work \
		--network=host \
		glevand/tdd-builder:latest '/work/build.sh'

	cp -av "${tmp_dir}/u-install" "${PROJECT_TOP}/"

	if [[ ${verbose} ]]; then
	{
		echo "-----------------"
		echo "${PROJECT_TOP}/u-install/bin:"
		ls -l "${PROJECT_TOP}/u-install/bin"
		echo "-----------------"
	} >&2
	fi
}

host_install_extra() {
	true
}

build_on_exit() {
	rm -rf "${PROJECT_TOP}/u-install"
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

export project_name='tdd-net-scanner'
export project_from='debian'
export project_description='Builds a docker image that contains tools for gathering information about a network.'

VERSION="${VERSION:-2}"

export extra_build_args=''

source ${DOCKER_TOP}/build-common.sh
