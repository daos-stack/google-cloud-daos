#!/usr/bin/env bash
# Copyright 2022 Intel Corporation
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
trap 'echo "Hit an unexpected and unchecked error. Exiting."' ERR

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
TMP_DIR=$(realpath "${SCRIPT_DIR}/../.tmp")
TF_DIR=$(realpath "${SCRIPT_DIR}/../")
CLIENT_FILES_DIR=$(realpath "${SCRIPT_DIR}/../client_files")
CONFIG_DIR=$(realpath "${SCRIPT_DIR}/../config")
ACTIVE_CONFIG_SYMLINK="${CONFIG_DIR}/active_config.sh"

# shellcheck source=_log.sh
source "${SCRIPT_DIR}/_log.sh"

# shellcheck disable=SC2034
LOG_LEVEL="DEBUG"

# active_config.sh is a symlink to the last config file used by start.sh
# shellcheck source=/dev/null
# Source the active config file that was last used by ./start.sh
if [[ ! -L "${ACTIVE_CONFIG_SYMLINK}" ]]; then
  log.error "No Active Configuration!"
  log.error "'${ACTIVE_CONFIG_SYMLINK}' symlink does not exist."
  log.error "Either the start.sh script was never run or it did not run successfully."
  log.error "Unable to perform 'terraform destroy'"
  exit 1
fi

# Source the last configuration that was used by the start.sh script
# shellcheck source=/dev/null
source "$(readlink "${ACTIVE_CONFIG_SYMLINK}")"

log.section "Destroying DAOS Servers & Clients"
cd "${TF_DIR}"
terraform destroy -auto-approve
ret=$?

log.debug "ret=$ret"

# Only clean up if terraform destroy was successful
if [ $ret -eq 0 ]; then

  if [[ -f "${SCRIPT_DIR}/login.sh" ]]; then
    rm -f "${SCRIPT_DIR}/login.sh"
  fi

  if [[ -f "${CLIENT_FILES_DIR}/hosts_clients" ]]; then
    rm -f "${CLIENT_FILES_DIR}/hosts_clients"
  fi

  if [[ -f "${CLIENT_FILES_DIR}/hosts_servers" ]]; then
    rm -f "${CLIENT_FILES_DIR}/hosts_servers"
  fi

  if [[ -f "${CLIENT_FILES_DIR}/hosts_all" ]]; then
    rm -f "${CLIENT_FILES_DIR}/hosts_all"
  fi

  # Clean up the ./tmp directory
  if [[ -d "${TMP_DIR}" ]]; then
    rm -r "${TMP_DIR}"
  fi

  if [[ -f "${TF_DIR}/terraform.tfstate" ]]; then
    rm -f "${TF_DIR}/terraform.tfstate"
    rm -f "${TF_DIR}/terraform.tfstate.backup"
  fi

  if [[ -f "${TF_DIR}/.terraform.lock.hcl" ]]; then
    rm -f "${TF_DIR}/.terraform.lock.hcl"
  fi

  if [[ -f "${TF_DIR}/terraform.tfvars" ]]; then
    rm -f "${TF_DIR}/terraform.tfvars"
  fi

  if [[ -f "${TF_DIR}/tfplan" ]]; then
    rm -f "${TF_DIR}/tfplan"
  fi

  if [[ -d "${TF_DIR}/.terraform" ]]; then
    rm -rf "${TF_DIR}/.terraform"
  fi

  # Remove the symlink to the last configuration
  if [[ -L "${ACTIVE_CONFIG_SYMLINK}" ]]; then
    rm -f "${ACTIVE_CONFIG_SYMLINK}"
  fi

fi
