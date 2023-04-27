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

#
# Runs Terraform to create DAOS Server and Client instances.
# Copies necessary files to clients to allow the IO500 benchmark to be run.
#
# Since some GCP projects are not set up to use os-login this script generates
# an SSH for the daos-user account that exists in the instances. You can then
# use the generated key to log into the first daos-client instance which
# is used as a bastion host.
#

set -eo pipefail
trap 'echo "Hit an unexpected and unchecked error. Exiting."' ERR

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
SCRIPT_FILENAME=$(basename "${BASH_SOURCE[0]}")
TMP_DIR=$(realpath "${SCRIPT_DIR}/../.tmp")
SSH_CONFIG_FILE="${TMP_DIR}/ssh_config"
TF_DIR=$(realpath "${SCRIPT_DIR}/../")
IMAGES_DIR=$(realpath "${SCRIPT_DIR}/../images")
CLIENT_FILES_DIR=$(realpath "${SCRIPT_DIR}/../client_files")
CONFIG_DIR=$(realpath "${SCRIPT_DIR}/../config")
CONFIG_FILE="GCP-1C-1S8d-rf0.sh"

# shellcheck source=_log.sh
source "${SCRIPT_DIR}/_log.sh"

# shellcheck disable=SC2034
: "${LOG_LEVEL:="INFO"}"

# active_config.sh is a symlink to the last config file used by start.sh
# ACTIVE_CONFIG="${CONFIG_DIR}/active_config.sh"

# Use internal IP for SSH connection with the first daos client
USE_INTERNAL_IP=0

ERROR_MSGS=()

show_help() {
  cat <<EOF

Usage:

  ${SCRIPT_FILENAME} <options>

  Deploy a DAOS cluster using terraform.
  Uses custom images specifically for IO500 runs.

Options:

  [ -l --list-configs ]           List available configuration
                                  files that can be passed in the
                                  -c --config option

  [ -c --config   CONFIG_FILE ]   Name of a configuration file in
                                  the config/ directory
                                  Default: ${CONFIG_FILE}

  [ -v --version  DAOS_VERSION ]  Version of DAOS to install

  [ -u --repo-baseurl DAOS_REPO_BASE_URL ] Base URL of a repo.

  [ -i --internal-ip ]            Use internal IP for SSH to the first client

  [ -f --force ]                  Force images to be re-built

  [ -h --help ]                   Show help

Examples:

  Deploy a DAOS environment with a specifc configuration

    ${SCRIPT_FILENAME} -c ./config/config_1c_1s_8d.sh

EOF
}

show_errors() {
  # If there are errors, print the error messages and exit
  if [[ ${#ERROR_MSGS[@]} -gt 0 ]]; then
    # shellcheck disable=SC2034
    for msg in "${ERROR_MSGS[@]}"; do
      log.error "${ERROR_MSGS[@]}"
    done
    #show_help
    exit 1
  fi
}

check_dependencies() {
  # Exit if gcloud command not found
  if ! gcloud -v &>/dev/null; then
    log.error "'gcloud' command not found
       Is the Google Cloud Platform SDK installed?
       See https://cloud.google.com/sdk/docs/install"
    exit 1
  fi
  # Exit if terraform command not found
  if ! terraform -v &>/dev/null; then
    log.error "'terraform' command not found
       Is Terraform installed?"
    exit 1
  fi
}

list_configs() {
  log.section "List of Configuration Files"
  # shellcheck disable=SC2010
  ls -1v config/ | grep -v active_config.sh | sort -t '-' -k2,2n -k3,3n -k4,4n
  echo "
Run start.sh -c <config_file_name>

If start.sh is run without the -c option then the '${CONFIG_FILE}' will be used.
  "
  exit
}

opts() {

  # shift will cause the script to exit if attempting to shift beyond the
  # max args.  So set +e to continue processing when shift errors.
  set +e
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --list-configs | -l)
      list_configs
      ;;
    --config | -c)
      CONFIG_FILE="$2"
      if [[ "${CONFIG_FILE}" == -* ]] || [[ "${CONFIG_FILE}" == "" ]] || [[ -z ${CONFIG_FILE} ]]; then
        ERROR_MSGS+=("ERROR: Missing CONFIG_FILE value for -c or --config")
        break
      elif [[ ! -f "${CONFIG_DIR}/${CONFIG_FILE}" ]]; then
        ERROR_MSGS+=("ERROR: Configuration file '${CONFIG_FILE}' not found.")
      fi
      export CONFIG_FILE
      shift 2
      ;;
    --internal-ip | -i)
      USE_INTERNAL_IP=1
      shift
      ;;
    --version | -v)
      DAOS_VERSION="${2}"
      if [[ "${DAOS_VERSION}" == -* ]] || [[ "${DAOS_VERSION}" = "" ]] || [[ -z ${DAOS_VERSION} ]]; then
        log.error "Missing DAOS_VERSION value for -v or --version"
        show_help
        exit 1
      fi
      export DAOS_VERSION
      shift 2
      ;;
    --repo-baseurl | -u)
      DAOS_REPO_BASE_URL="${2}"
      if [[ "${DAOS_REPO_BASE_URL}" == -* ]] || [[ "${DAOS_REPO_BASE_URL}" = "" ]] || [[ -z ${DAOS_REPO_BASE_URL} ]]; then
        log.error "Missing URL value for -u or --repo-baseurl"
        show_help
        exit 1
      fi
      export DAOS_REPO_BASE_URL
      shift 2
      ;;
    --force | -f)
      DAOS_FORCE_REBUILD=1
      export DAOS_FORCE_REBUILD
      shift
      ;;
    --help | -h)
      show_help
      exit 0
      ;;
    --* | -*)
      ERROR_MSGS+=("ERROR: Unrecognized option '${1}'")
      shift
      break
      ;;
    *)
      ERROR_MSGS+=("ERROR: Unrecognized option '${1}'")
      shift
      break
      ;;
    esac
  done
  set -eo pipefail

  show_errors
}

load_config() {
  local config_path="${CONFIG_DIR}/${CONFIG_FILE}"
  local active_config_path="${CONFIG_DIR}/active_config.sh"
  local current_config

  if [[ -L "${active_config_path}" ]]; then
    current_config="$(readlink "${active_config_path}")"
    if [[ "$(basename "${config_path}")" != $(basename "${current_config}") ]]; then
      log.error "
  Cannot use configuration: ${CONFIG_FILE}

  The '$(basename "${current_config}")' configuration is currently active.

  You must run stop.sh before running

  ${SCRIPT_FILENAME} -c ${CONFIG_FILE}

"
      exit 1
    fi
  else
    ln -snf "${config_path}" "${active_config_path}"
  fi

  log.info "Sourcing config file: ${active_config_path}"
  # shellcheck source=/dev/null
  source "${active_config_path}"

  # Modify instance base names if RESOURCE_PREFIX variable is set
  DAOS_SERVER_BASE_NAME="${DAOS_SERVER_BASE_NAME:-daos-server}"
  DAOS_CLIENT_BASE_NAME="${DAOS_CLIENT_BASE_NAME:-daos-client}"
  if [[ -n ${RESOURCE_PREFIX} ]]; then
    DAOS_SERVER_BASE_NAME="${RESOURCE_PREFIX}-${DAOS_SERVER_BASE_NAME}"
    DAOS_CLIENT_BASE_NAME="${RESOURCE_PREFIX}-${DAOS_CLIENT_BASE_NAME}"
  fi

  # shellcheck disable=SC2046
  {
    export $(compgen -v | grep "^DAOS_")
    export $(compgen -v | grep "^IO500_")
    export $(compgen -v | grep "^GCP_")
  }
}

create_hosts_files() {

  # pdsh or clush commands will need to be run from the first daos-client
  # instance. Those commands will need to take a file which contains a list of
  # hosts.  This function creates 3 files:
  #    hosts_clients - a list of daos-client* hosts
  #    hosts_servers - a list of daos-server* hosts
  #    hosts_all     - a list of all hosts
  # The copy_files_to_first_client function in this script will copy the hosts_* files to
  # the first daos-client instance.

  unset CLIENTS
  unset SERVERS
  unset ALL_NODES

  HOSTS_CLIENTS_FILE="${CLIENT_FILES_DIR}/hosts_clients"
  HOSTS_SERVERS_FILE="${CLIENT_FILES_DIR}/hosts_servers"
  HOSTS_ALL_FILE="${CLIENT_FILES_DIR}/hosts_all"

  rm -f "${HOSTS_CLIENTS_FILE}" "${HOSTS_SERVERS_FILE}" "${HOSTS_ALL_FILE}"

  for ((i = 1; i <= DAOS_CLIENT_INSTANCE_COUNT; i++)); do
    CLIENTS+="${DAOS_CLIENT_BASE_NAME}-$(printf "%04d" "${i}") "
    echo "${DAOS_CLIENT_BASE_NAME}-$(printf "%04d" "${i}")" >>"${HOSTS_CLIENTS_FILE}"
    echo "${DAOS_CLIENT_BASE_NAME}-$(printf "%04d" "${i}")" >>"${HOSTS_ALL_FILE}"
  done

  for ((i = 1; i <= DAOS_SERVER_INSTANCE_COUNT; i++)); do
    SERVERS+="${DAOS_SERVER_BASE_NAME}-$(printf "%04d" "${i}") "
    echo "${DAOS_SERVER_BASE_NAME}-$(printf "%04d" "${i}")" >>"${HOSTS_SERVERS_FILE}"
    echo "${DAOS_SERVER_BASE_NAME}-$(printf "%04d" "${i}")" >>"${HOSTS_ALL_FILE}"
  done

  DAOS_FIRST_CLIENT=$(echo "${CLIENTS}" | awk '{print $1}')
  DAOS_FIRST_SERVER=$(echo "${SERVERS}" | awk '{print $1}')
  ALL_NODES="${SERVERS} ${CLIENTS}"

  export CLIENTS
  export DAOS_FIRST_CLIENT
  export HOSTS_CLIENTS_FILE
  export SERVERS
  export DAOS_FIRST_SERVER
  export HOSTS_SERVERS_FILE
  export ALL_NODES

}

build_disk_images() {
  # Build the DAOS disk images
  log.section "IO500 Disk Images"
  if [[ $DAOS_FORCE_REBUILD -eq 1 ]]; then
    "${IMAGES_DIR}/build_io500_images.sh" --force
  else
    "${IMAGES_DIR}/build_io500_images.sh"
  fi
}

run_terraform() {
  log.section "Deploying DAOS Servers and Clients using Terraform"
  cd "${TF_DIR}"
  terraform init -input=false
  terraform plan -out=tfplan -input=false
  terraform apply -input=false tfplan
}

create_tfvars() {

  cat >"${TF_DIR}/terraform.tfvars" <<EOF
# Variables for both Servers and Clients
project_id         = "${GCP_PROJECT_ID}"
network_name       = "${GCP_NETWORK_NAME}"
subnetwork_name    = "${GCP_SUBNETWORK_NAME}"
subnetwork_project = "${GCP_PROJECT_ID}"
region             = "${GCP_REGION}"
zone               = "${GCP_ZONE}"
allow_insecure     = "${DAOS_ALLOW_INSECURE}"

# Servers
server_daos_crt_timeout     = ${DAOS_SERVER_CRT_TIMEOUT}
server_daos_disk_count      = ${DAOS_SERVER_DISK_COUNT}
server_daos_scm_size        = ${DAOS_SERVER_SCM_SIZE}
server_gvnic                = ${DAOS_SERVER_GVNIC}
server_instance_base_name   = "${DAOS_SERVER_BASE_NAME}"
server_machine_type         = "${DAOS_SERVER_MACHINE_TYPE}"
server_number_of_instances  = ${DAOS_SERVER_INSTANCE_COUNT}
server_os_family            = "${DAOS_SERVER_IMAGE_FAMILY}"
server_os_project           = "${GCP_PROJECT_ID}"

# Clients
client_gvnic               = ${DAOS_CLIENT_GVNIC}
client_instance_base_name  = "${DAOS_CLIENT_BASE_NAME}"
client_machine_type        = "${DAOS_CLIENT_MACHINE_TYPE}"
client_number_of_instances = ${DAOS_CLIENT_INSTANCE_COUNT}
client_os_family           = "${DAOS_CLIENT_IMAGE_FAMILY}"
client_os_project          = "${GCP_PROJECT_ID}"

EOF
}

configure_first_client_ip() {
  log.debug "DAOS_FIRST_CLIENT=${DAOS_FIRST_CLIENT}"
  # shellcheck disable=SC2154
  if [[ "${USE_INTERNAL_IP}" -eq 1 ]]; then
    # shellcheck disable=SC2154

    FIRST_CLIENT_IP=$(gcloud compute instances describe "${DAOS_FIRST_CLIENT}" \
      --project="${GCP_PROJECT_ID}" \
      --zone="${GCP_ZONE}" \
      --format="value(networkInterfaces[0].networkIP)")
  else
    # Check to see if first client instance has an external IP.
    # If it does, then don't attempt to add an external IP again.
    FIRST_CLIENT_IP=$(gcloud compute instances describe "${DAOS_FIRST_CLIENT}" \
      --project="${GCP_PROJECT_ID}" \
      --zone="${GCP_ZONE}" \
      --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

    if [[ -z "${FIRST_CLIENT_IP}" ]]; then
      log.info "Add external IP to first client"

      gcloud compute instances add-access-config "${DAOS_FIRST_CLIENT}" \
        --project="${GCP_PROJECT_ID}" \
        --zone="${GCP_ZONE}" &&
        sleep 10

      FIRST_CLIENT_IP=$(gcloud compute instances describe "${DAOS_FIRST_CLIENT}" \
        --project="${GCP_PROJECT_ID}" \
        --zone="${GCP_ZONE}" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    fi
  fi
}

configure_ssh() {
  # TODO: Need improvements here.
  #       Using os_login is preferred but after some users ran into issues with it
  #       this turned out to be the method that worked for most users.
  #       This function generates a key pair and an ssh config file that is
  #       used to log into the first daos-client node as the 'daos-user' user.
  #       This isn't ideal in team situations where a team member who was not
  #       the one who ran this start.sh script needs to log into the instances
  #       as the 'daos-user' in order to run IO500 or do troubleshooting.
  #       If os-login was used, then project admins would be able to control
  #       who has access to the daos-* instances. Users would access the daos-*
  #       instances the same way they do all other instances in their project.

  log.section "Configure SSH on first client instance ${DAOS_FIRST_CLIENT}"

  mkdir -p "${TMP_DIR}"
  # Create an ssh key for the current IO500 example environment
  if [[ ! -f "${TMP_DIR}/id_rsa" ]]; then
    log.info "Generating SSH key pair"
    ssh-keygen -q -t rsa -b 4096 -C "${DAOS_SSH_USER}" -N '' -f "${TMP_DIR}/id_rsa" 2>&1
  fi
  chmod 600 "${TMP_DIR}/id_rsa"

  if [[ ! -f "${TMP_DIR}/id_rsa.pub" ]]; then
    log.error "Missing file: ${TMP_DIR}/id_rsa.pub"
    log.error "Unable to continue without id_rsa and id_rsa.pub files in ${TMP_DIR}"
    exit 1
  fi

  # Generate file containing keys which will be added to the metadata of all nodes.
  echo "${DAOS_SSH_USER}:$(cat "${TMP_DIR}/id_rsa.pub")" >"${TMP_DIR}/keys.txt"

  # Only update instance meta-data once
  if ! gcloud compute instances describe "${DAOS_FIRST_CLIENT}" \
    --project="${GCP_PROJECT_ID}" \
    --zone="${GCP_ZONE}" \
    --format='value[](metadata.items.ssh-keys)' | grep -q "${DAOS_SSH_USER}"; then

    log.info "Disable os-login and add '${DAOS_SSH_USER}' SSH key to metadata on all instances"
    for node in ${ALL_NODES}; do
      echo "Updating metadata for ${node}"
      # Disable OSLogin to be able to connect with SSH keys uploaded in next command
      gcloud compute instances add-metadata "${node}" \
        --project="${GCP_PROJECT_ID}" \
        --zone="${GCP_ZONE}" \
        --metadata enable-oslogin=FALSE &&
        # Upload SSH key to instance, so that you can log into instance via SSH
        gcloud compute instances add-metadata "${node}" \
          --project="${GCP_PROJECT_ID}" \
          --zone="${GCP_ZONE}" \
          --metadata-from-file ssh-keys="${TMP_DIR}/keys.txt" &
    done
    # Wait for instance meta-data updates to finish
    wait
  fi

  # Create ssh config for all instances
  cat >"${TMP_DIR}/instance_ssh_config" <<EOF
Host *
    CheckHostIp no
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
    LogLevel ERROR
EOF
  chmod 600 "${TMP_DIR}/instance_ssh_config"

  # Create local ssh config
  cat >"${SSH_CONFIG_FILE}" <<EOF
Include ~/.ssh/config
Include ~/.ssh/config.d/*

Host ${FIRST_CLIENT_IP}
    CheckHostIp no
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    IdentitiesOnly yes
    LogLevel ERROR
    User ${DAOS_SSH_USER}
    IdentityFile ${TMP_DIR}/id_rsa

EOF
  chmod 600 "${SSH_CONFIG_FILE}"

  log.info "Copy SSH key to first DAOS client instance ${DAOS_FIRST_CLIENT}"

  log.debug "Create ~/.ssh directory on first daos-client instance"
  ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" \
    "mkdir -m 700 -p ~/.ssh"

  log.debug "Copy SSH key pair to first daos-client instance"
  scp -q -F "${SSH_CONFIG_FILE}" \
    "${TMP_DIR}/id_rsa" \
    "${TMP_DIR}/id_rsa.pub" \
    "${FIRST_CLIENT_IP}:~/.ssh/"

  log.debug "Copy SSH config to first daos-client instance and set permissions"
  scp -q -F "${SSH_CONFIG_FILE}" \
    "${TMP_DIR}/instance_ssh_config" \
    "${FIRST_CLIENT_IP}:~/.ssh/config"
  ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" \
    "chmod -R 600 ~/.ssh/*"

  log.debug "Create ${SCRIPT_DIR}/login"
  echo "#!/usr/bin/env bash
  ssh -F ${TMP_DIR}/ssh_config ${FIRST_CLIENT_IP}
  " >"${SCRIPT_DIR}/login.sh"
  chmod +x "${SCRIPT_DIR}/login.sh"
}

copy_files_to_first_client() {
  # Copy the files that will be needed in order to run pdsh, clush and other
  # commands on the first daos-client instance

  log.info "Copy files to first client ${DAOS_FIRST_CLIENT}"

  scp -F "${SSH_CONFIG_FILE}" \
    "${SCRIPT_DIR}/_log.sh" \
    "${DAOS_SSH_USER}"@"${FIRST_CLIENT_IP}":~/

  # Copy the config file for the IO500 environment
  scp -F "${SSH_CONFIG_FILE}" \
    "${CONFIG_DIR}/${CONFIG_FILE}" \
    "${DAOS_SSH_USER}"@"${FIRST_CLIENT_IP}":~/config.sh

  scp -r -F "${SSH_CONFIG_FILE}" \
    "${CLIENT_FILES_DIR}"/* \
    "${DAOS_SSH_USER}"@"${FIRST_CLIENT_IP}":~/

  ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" \
    "chmod +x ~/*.sh && chmod -x ~/config.sh"
}

copy_ssh_keys_to_all_nodes() {
  # Clear ~/.ssh/known_hosts so we don't run into any issues
  ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" \
    "clush --hostfile=hosts_all --dsh 'rm -f ~/.ssh/known_hosts'"

  # Copy ~/.ssh directory to all instances
  ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" \
    "clush --hostfile=hosts_all --dsh --copy ~/.ssh --dest ~/"
}

wait_for_startup_script_to_finish() {
  ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" \
    "printf 'Waiting for startup script to finish\n'
     until sudo journalctl -u google-startup-scripts.service --no-pager | grep 'Finished running startup scripts.'
     do
       printf '.'
       sleep 5
     done
     printf '\n'
    "
}

set_permissions_on_cert_files() {
  if [[ "${DAOS_ALLOW_INSECURE}" == "false" ]]; then
    ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" \
      "clush --hostfile=hosts_clients --dsh sudo chown ${DAOS_SSH_USER}:${DAOS_SSH_USER} /etc/daos/certs/daosCA.crt"

    ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" \
      "clush --hostfile=hosts_clients --dsh sudo chown ${DAOS_SSH_USER}:${DAOS_SSH_USER} /etc/daos/certs/admin.*"
  fi
}

show_instances() {
  log.section "DAOS Server and Client instances"
  DAOS_FILTER="$(echo "${DAOS_SERVER_BASE_NAME}" | sed -r 's/server/.*/g')-.*"
  gcloud compute instances list \
    --project="${GCP_PROJECT_ID}" \
    --zones="${GCP_ZONE}" \
    --filter="name~'^${DAOS_FILTER}'"
}

check_gvnic() {
  DAOS_SERVER_NETWORK_TYPE=$(ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" "ssh ${DAOS_FIRST_SERVER} 'sudo lshw -class network'" | sed -n "s/^.*product: \(.*\$\)/\1/p")
  DAOS_CLIENT_NETWORK_TYPE=$(ssh -q -F "${SSH_CONFIG_FILE}" "${FIRST_CLIENT_IP}" "sudo lshw -class network" | sed -n "s/^.*product: \(.*\$\)/\1/p")
  log.debug "Network adapters type:"
  log.debug "DAOS_SERVER_NETWORK_TYPE = ${DAOS_SERVER_NETWORK_TYPE}"
  log.debug "DAOS_CLIENT_NETWORK_TYPE = ${DAOS_CLIENT_NETWORK_TYPE}"
}

show_run_steps() {

  log.section "DAOS Server and Client instances are ready for IO500 run"

  cat <<EOF

To run the IO500 benchmark:

1. Log into the first client
   bin/login.sh

2. Run IO500
   ./run_io500-sc22.sh

EOF
}

main() {
  # check_dependencies
  opts "$@"
  load_config
  build_disk_images
  create_tfvars
  run_terraform
  create_hosts_files
  configure_first_client_ip
  configure_ssh
  copy_files_to_first_client
  copy_ssh_keys_to_all_nodes
  wait_for_startup_script_to_finish
  set_permissions_on_cert_files
  show_instances
  check_gvnic
  show_run_steps
}

main "$@"
