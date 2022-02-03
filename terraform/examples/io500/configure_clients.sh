#!/bin/bash
#
# Copies the /etc/daos/daos_agent.yml and /etc/daos/daos_control.yml
# files from the first server instance.
#
# This assumes that the DAOS servers and clients have pdsh and clush installed
#

DAOS_FIRST_SERVER=$(head -n 1 ~/hosts_servers)

log() {
  if [[ -t 1 ]]; then tput setaf 14; fi
  printf -- "\n%s\n\n" "${1}"
  if [[ -t 1 ]]; then tput sgr0; fi
}

# Clear ~/.ssh/known_hosts so we don't run into any issues
clush --hostfile=hosts_all --dsh 'rm -f ~/.ssh/known_hosts'

# Copy ~/.ssh directory to all instances
pdcp -w^hosts_all -r ~/.ssh ~/

# Get agent config files from first daos-server instance
log "Getting /etc/daos/daos_agent.yml and /etc/daos/daos_control.yml from ${DAOS_FIRST_SERVER}"
scp ${DAOS_FIRST_SERVER}:/etc/daos/daos_agent.yml ~/
scp ${DAOS_FIRST_SERVER}:/etc/daos/daos_control.yml ~/

log "Config files retrieved from ${DAOS_FIRST_SERVER}"
ls -alFh ~/*.yml
echo

# Copy daos_agent.yml and daos_agent.yml to all clients
log "Stopping daos_agent on all clients"
clush --hostfile=hosts_clients --dsh 'sudo systemctl stop daos_agent'

log "Copying ~/daos_agent.yml to /etc/daos/daos_agent.yml all clients"
cd ~/
clush --hostfile=hosts_clients --dsh --copy 'daos_agent.yml' --dest 'daos_agent.yml'
clush --hostfile=hosts_clients --dsh 'sudo cp -f daos_agent.yml /etc/daos/'

log "Copying ~/daos_control.yml to /etc/daos/daos_control.yml all clients"
clush --hostfile=hosts_clients --dsh --copy 'daos_control.yml' --dest 'daos_control.yml'
clush --hostfile=hosts_clients --dsh 'sudo cp -f daos_control.yml /etc/daos/'

log "Starting daos_agent on all clients"
clush --hostfile=hosts_clients --dsh 'sudo systemctl start daos_agent'

rm -f ~/daos_agent.yml
rm -f ~/daos_control.yml
