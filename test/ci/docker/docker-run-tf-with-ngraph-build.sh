#!  /bin/bash

# ==============================================================================
#  Copyright 2018 Intel Corporation
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# ==============================================================================

# Script parameters:
#
# $1 ImageID    Required: ID of the ngtf_bridge_ci docker image to use
# $2 TFdir      Required: tensorflow directory to build
#
# Script environment variable parameters:
#
# NG_TF_PY_VERSION   Optional: Set python major version ("2" or "3", default=2)

set -e  # Fail on any command with non-zero exit

tf_dir="${2}"
if [ ! -d "${tf_dir}" ] ; then
    echo 'Please provide the name of the tensorflow directory you want to build, as the 2nd parameter'
    exit 1
fi

# Set defaults

if [ -z "${NG_TF_PY_VERSION}" ] ; then
    NG_TF_PY_VERSION='2'  # Default is Python 2
fi

# Note that the docker image must have been previously built using the
# make-docker-ngraph-tf-ci.sh script (in the same directory as this script).
#
case "${NG_TF_PY_VERSION}" in
    2)
        IMAGE_CLASS='ngraph_tf_ci_py2'
        ;;
    3)
        IMAGE_CLASS='ngraph_tf_ci_py3'
        ;;
    *)
        echo 'NG_TF_PY_VERSION must be set to "2", "3", or left unset (default is "2")'
        exit 1
        ;;
esac
IMAGE_ID="${1}"
if [ -z "${IMAGE_ID}" ] ; then
    echo 'Please provide an image version as the first parameter'
    exit 1
fi

# Find the top-level bridge directory, so we can mount it into the docker
# container
bridge_dir="$(realpath ../../..)"

bridge_mountpoint='/home/dockuser/ngraph-tf'
tf_mountpoint='/home/dockuser/tensorflow'

# Set up a bunch of volume mounts
volume_mounts='-v /dataset:/dataset'
volume_mounts="${volume_mounts} -v ${bridge_dir}:${bridge_mountpoint}"
volume_mounts="${volume_mounts} -v ${tf_dir}:${tf_mountpoint}"
if [ -z "${NG_TF_TRAINED}" ] ; then
  volume_mounts="${volume_mounts} -v /trained_dataset:/trained_dataset"
else
  trained_abspath="$(realpath ${NG_TF_TRAINED})"
  volume_mounts="${volume_mounts} -v ${trained_abspath}:/trained_dataset"
fi

# Set up optional environment variables
optional_env=''
if [ ! -z "${NG_TF_PY_VERSION}" ] ; then
  optional_env="${optional_env} --env NG_TF_PY_VERSION=${NG_TF_PY_VERSION}"
fi

set -u  # No unset variables after this point

RUNASUSER_SCRIPT="${bridge_mountpoint}/test/ci/docker/docker-scripts/run-as-user.sh"
BUILD_SCRIPT="${bridge_mountpoint}/test/ci/docker/docker-scripts/run-tf-with-ngraph-build.sh"

# If proxy settings are detected in the environment, make sure they are
# included on the docker-build command-line.  This mirrors a similar system
# in the Makefile.

if [ ! -z "${http_proxy}" ] ; then
    DOCKER_HTTP_PROXY="--env http_proxy=${http_proxy}"
else
    DOCKER_HTTP_PROXY=' '
fi

if [ ! -z "${https_proxy}" ] ; then
    DOCKER_HTTPS_PROXY="--env https_proxy=${https_proxy}"
else
    DOCKER_HTTPS_PROXY=' '
fi

docker run --rm \
       --env RUN_UID="$(id -u)" \
       --env RUN_CMD="${BUILD_SCRIPT}" \
       ${optional_env} \
       ${DOCKER_HTTP_PROXY} ${DOCKER_HTTPS_PROXY} \
       ${volume_mounts} \
       "${IMAGE_CLASS}:${IMAGE_ID}" "${RUNASUSER_SCRIPT}"


