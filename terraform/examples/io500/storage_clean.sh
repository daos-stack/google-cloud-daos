#!/bin/bash
#
# Clean storage on DAOS servers
#

set -e
trap 'echo "Hit an unexpected and unchecked error. Exiting."' ERR

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

# Source config file to load variables
source "${CONFIG_FILE}"

log() {
  if [[ -t 1 ]]; then tput setaf 14; fi
  printf -- "\n%s\n\n" "${1}"
  if [[ -t 1 ]]; then tput sgr0; fi
}

clean_server() {
  server="$1"
  log "Cleaning ${server}"
  ssh ${server} "rm -f .ssh/known_hosts"
  ssh ${server} "sudo systemctl stop daos_server"
  ssh ${server} "sudo rm -rf /var/daos/ram/*"
  ssh ${server} "sudo umount /var/daos/ram/ && echo success || echo unmounted"

  # TODO: Move nr_hugepages out of this script.
  #       daos_server.yml settings should not be modified here.
  #       Server configuration should be handled by Terraform or startup
  #       scripts.
  #       Here we are forced to source config.sh file because we need
  #       need DAOS_SERVER_* variables. This really should not need to be
  #       done.
  #

  # Set nr_hugepages value
  # nr_hugepages = (targets * 1Gib) / hugepagesize
  #    Example: for 8 targets and Hugepagesize = 2048 kB:
  #       Targets = 8
  #       1Gib = 1048576 KiB
  #       Hugepagesize = 2048kB
  #       nr_hugepages=(8*1048576) / 2048
  #       So nr_hugepages value is 4096
  hugepagesize=$(ssh ${server} "grep Hugepagesize /proc/meminfo | awk '{print \$2}'")
  nr_hugepages=$(( (${DAOS_SERVER_DISK_COUNT}*1048576) / ${hugepagesize} ))
  ssh ${server} "sudo sed -i \"s/^nr_hugepages:.*/nr_hugepages: ${nr_hugepages}/g\" /etc/daos/daos_server.yml"

  ssh ${server} "sudo sed -i \"s/^crt_timeout:.*/crt_timeout: ${DAOS_SERVER_CRT_TIMEOUT}/g\" /etc/daos/daos_server.yml"

  # storage settings
  ssh ${server} "sudo sed -i \"s/^\(\s*\)targets:.*/\1targets: ${DAOS_SERVER_DISK_COUNT}/g\" /etc/daos/daos_server.yml"
  ssh ${server} "sudo sed -i \"s/^\(\s*\)scm_size:.*/\1scm_size: ${DAOS_SERVER_SCM_SIZE}/g\" /etc/daos/daos_server.yml"

  ssh ${server} "cat /etc/daos/daos_server.yml"
  ssh ${server} "sudo systemctl start daos_server"
  sleep 4
  ssh ${server} "sudo systemctl status daos_server"
  printf "\nFinished cleaning ${server}\n\n"
}

while read s; do
  clean_server "$s"
done <"${SCRIPT_DIR}/hosts_servers"
