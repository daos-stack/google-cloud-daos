#!/usr/bin/env bash
# Copyright 2023 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eo pipefail
trap 'echo "Unexpected and unchecked error. Exiting." && cleanup' ERR
trap cleanup INT

: "${GCP_PROJECT:=$(gcloud info --format="value(config.project)")}"
: "${DAOS_FORCE_REBUILD:=0}"
: "${DAOS_ENV_FILE:="build.env"}"
: "${LOG_LEVEL:=INFO}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
SCRIPT_FILENAME=$(basename "${BASH_SOURCE[0]}")

# shellcheck disable=SC2034
START_TIMESTAMP=$(date "+%FT%T")

REPO_ROOT_DIR=$(realpath "${SCRIPT_DIR}/../../../../")
IMAGES_DIR="${REPO_ROOT_DIR}/images"

# Get the name of the Packer template from the build.sh script.
# This way we don't have that variable declared in 2 different locations.
# shellcheck disable=SC2016
DAOS_SRC_PACKER_TEMPLATE=$(grep ': "${DAOS_PACKER_TEMPLATE:="' "${IMAGES_DIR}/build.sh" | sed -e 's/^.*="\([^"]*\)".*$/\1/')
DAOS_IO500_PACKER_TEMPLATE="i500-${DAOS_SRC_PACKER_TEMPLATE}"
DAOS_IO500_PACKER_VARS_FILE="${DAOS_IO500_PACKER_TEMPLATE//pkr/pkrvars}"

# BEGIN: Logging variables and functions
declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4 [OFF]=5)
declare -A LOG_COLORS=([DEBUG]=2 [INFO]=12 [WARN]=3 [ERROR]=1 [FATAL]=9 [OFF]=0 [OTHER]=15)

log() {
  local msg="$1"
  local lvl=${2:-INFO}
  if [[ ${LOG_LEVELS[$LOG_LEVEL]} -le ${LOG_LEVELS[$lvl]} ]]; then
    if [[ -t 1 ]]; then tput setaf "${LOG_COLORS[$lvl]}"; fi
    printf "[%-5s] %s\n" "$lvl" "${msg}" 1>&2
    if [[ -t 1 ]]; then tput sgr0; fi
  fi
}

log.debug() { log "${1}" "DEBUG"; }
log.info() { log "${1}" "INFO"; }
log.warn() { log "${1}" "WARN"; }
log.error() { log "${1}" "ERROR"; }
log.fatal() { log "${1}" "FATAL"; }
# END: Logging variables and functions

show_help() {

  cat <<EOF

Usage:

  ${SCRIPT_FILENAME} [<options>]

  Build DAOS Server and Client IO500 images.

  This script does the following:

  1. Copies
     ${SCRIPT_DIR}/ansible_playbooks/*
     to
     ${IMAGES_DIR}/ansible_playbooks

  2. Makes a copy of the DAOS packer template to
     ${IMAGES_DIR}/${DAOS_PACKER_TEMPLATE}
     and then modifies it to add additional provisioners
     that run each playbook copied in the previous step.

  3. Sets the environment variables for
     ${IMAGES_DIR}/build.sh
     so that
         - The modified packer template '${DAOS_PACKER_TEMPLATE}' is used
         - All environment variables from the file specified in
           ${SCRIPT_DIR}/${DAOS_ENV_FILE}
           are exported. This overrides the default environment
           vars to customize the image family name.

  4. Runs ${IMAGES_DIR}/build.sh
     to build the custom DAOS I0500 images

  5. Cleans up
       - Deletes any playbooks that were copied to
         ${IMAGES_DIR}/ansible_playbooks
       - Deletes the modified packer template
         ${IMAGES_DIR}/${DAOS_PACKER_TEMPLATE}

Options:

  [ -e --env-file DAOS_ENV_FILE ] Environment vars file

  [ -f --force ]                  Force build even if images exist

  [ -h --help ]                   Show this help

Environment Variables:

  Environment Variable  Default Value  Current Value
  --------------------  -------------  ----------------
  DAOS_ENV_FILE         build.env      ${DAOS_ENV_FILE}
  DAOS_FORCE_REBUILD    false          ${DAOS_FORCE_REBUILD}

  The DAOS_ENV_FILE should contain a filename of a file
  that contains the environment varibles for the
  <repo_root>/image/build.sh file.

  The DAOS_ENV_FILE will be sourced before running
  <repo_root>/image/build.sh

EOF
}

opts() {
  # shift will cause the script to exit if attempting to shift beyond the
  # max args.  So set +e to continue processing when shift errors.
  set +e
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --help | -h)
      show_help
      exit 0
      ;;
    --env-file | -e)
      DAOS_ENV_FILE="$2"
      if [[ "${DAOS_ENV_FILE}" == -* ]] || [[ "${DAOS_ENV_FILE}" = "" ]] || [[ -z ${DAOS_INSTALL_TYPE} ]]; then
        log.error "Missing DAOS_ENV_FILE value for -e or --env-file"
        exit 1
      fi
      shift 2
      ;;
    --force | -f)
      DAOS_FORCE_REBUILD=1
      export DAOS_FORCE_REBUILD
      shift
      ;;
    --)
      break
      ;;
    --* | -*)
      log.error "Unrecognized option '${1}'"
      show_help
      exit 1
      ;;
    *)
      log.error "Unrecognized option '${1}'"
      shift
      break
      ;;
    esac
  done
  set -e
}

load_env() {
  if [[ ! -f "${SCRIPT_DIR}/${DAOS_ENV_FILE}" ]]; then
    log.error "DAOS_ENV_FILE=${DAOS_ENV_FILE}"
    log.error "File not found: ${SCRIPT_DIR}/${DAOS_ENV_FILE}"
    exit 1
  else
    # shellcheck disable=SC1090
    source "${SCRIPT_DIR}/${DAOS_ENV_FILE}"
  fi
}

copy_playbooks() {
  cp -f "${SCRIPT_DIR}/ansible_playbooks/io500.yml" "${IMAGES_DIR}/ansible_playbooks/io500.yml"
  mkdir -p "${IMAGES_DIR}/patches"
  for pf in "${SCRIPT_DIR}"/patches/*; do
    cp -f "${pf}" "${IMAGES_DIR}/patches/"
  done
}

create_pkr_template() {
  local pkr_template="${IMAGES_DIR}/${DAOS_IO500_PACKER_TEMPLATE}"
  log.debug "Creating Packer Template: ${pkr_template}"
  cp -f "${IMAGES_DIR}/${DAOS_SRC_PACKER_TEMPLATE}" "${pkr_template}"
  sed -i '$s/}/\n  provisioner "ansible-local" {\n    playbook_file = ".\/ansible_playbooks\/io500.yml"\n  }\n}/' "${pkr_template}"
  sed -i '$s/}/\n  provisioner "ansible-local" {\n    playbook_file = ".\/ansible_playbooks\/io500.yml"\n  }\n}/' "${pkr_template}"
  sed -i '/sources =.*/a\\n\ \ provisioner "file" {\n\ \ \ \ source      = "patches"\n\ \ \ \ destination = "/tmp/patches"\n\ \ }' "${pkr_template}"
}

cleanup() {
  local pkr_template="${IMAGES_DIR}/${DAOS_IO500_PACKER_TEMPLATE}"
  if [[ -f "${pkr_template}" ]]; then
    rm -f "${pkr_template}"
  fi

  local pkrvars_file="${IMAGES_DIR}/${DAOS_IO500_PACKER_VARS_FILE}"
  if [[ -f "${pkrvars_file}" ]]; then
    rm -f "${pkrvars_file}"
  fi

  local patches_dir="${IMAGES_DIR}/patches"
  if [[ -d "${patches_dir}" ]]; then
    rm -rf "${patches_dir}"
  fi

  rm -f "${IMAGES_DIR}/ansible_playbooks/io500.yml"
}

build() {
  log.debug "build()"

  load_env

  # Build Server Image
  SERVER_IMAGE=$(gcloud compute images list --project="${GCP_PROJECT}" --format='value(name)' --filter="name:${DAOS_SERVER_IMAGE_FAMILY}*" --limit=1)
  if [[ "${DAOS_FORCE_REBUILD}" -eq 1 ]] || [[ -z ${SERVER_IMAGE} ]]; then
    log.info "Building ${DAOS_SERVER_IMAGE_FAMILY} image"
    # Use the default packer template that does not run the io500 playbook
    export DAOS_INSTALL_TYPE="server"
    export DAOS_BUILD_CLIENT_IMAGE="false"
    export DAOS_BUILD_SERVER_IMAGE="true"
    export DAOS_PACKER_TEMPLATE="${DAOS_SRC_PACKER_TEMPLATE}"
    export DAOS_PACKER_VARS_FILE="${DAOS_IO500_PACKER_VARS_FILE}"
    "${IMAGES_DIR}"/build.sh
  else
    log.info "Skipping image build. ${DAOS_SERVER_IMAGE_FAMILY} image exists."
  fi

  # Build Client Image
  CLIENT_IMAGE=$(gcloud compute images list --project="${GCP_PROJECT}" --format='value(name)' --filter="name:${DAOS_CLIENT_IMAGE_FAMILY}*" --limit=1)
  if [[ "${DAOS_FORCE_REBUILD}" -eq 1 ]] || [[ -z ${CLIENT_IMAGE} ]]; then
    log.info "Building ${DAOS_CLIENT_IMAGE_FAMILY} image"
    # Use the modified packer template that runs the io500 playbook
    export DAOS_INSTALL_TYPE="client"
    export DAOS_BUILD_CLIENT_IMAGE="true"
    export DAOS_BUILD_SERVER_IMAGE="false"
    export DAOS_PACKER_TEMPLATE="${DAOS_IO500_PACKER_TEMPLATE}"
    export DAOS_PACKER_VARS_FILE="${DAOS_IO500_PACKER_VARS_FILE}"
    "${IMAGES_DIR}"/build.sh
  else
    log.info "Skipping image build. ${DAOS_CLIENT_IMAGE_FAMILY} image exists."
  fi
}

main() {
  opts "$@"
  log.info "Building DAOS IO500 images"
  copy_playbooks
  create_pkr_template
  build
  cleanup
  log.info "Finished building DAOS IO500 images"
  echo
}

main "$@"
