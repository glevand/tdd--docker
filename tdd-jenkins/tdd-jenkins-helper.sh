#!/bin/bash

set -ex

script_name="${0##*/}"

if [ ! -f /.dockerenv ]; then
	echo "${script_name}: ERROR: Startup helper for tdd-jenkins container." >&2
	exit 1
fi

stamp='/.jenkins-configured'

if [[ ! -f ${stamp} ]]; then
	sudo touch ${stamp}

	host_gid=$(stat --format=%g /var/run/docker.sock)

	for g in $(id --groups "${JENKINS_USER}"); do
		if [[ "${g}" == "${host_gid}" ]]; then
			found=1
			break;
		fi
	done

	if [[ ! ${found} ]]; then
		echo "${script_name}: ERROR: ${JENKINS_USER} not in docker group." >&2
	fi
fi

sudo chmod u-s /usr/sbin/gosu
exec /usr/local/bin/jenkins.sh
