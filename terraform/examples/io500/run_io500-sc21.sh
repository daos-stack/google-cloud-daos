#!/bin/bash
#
# Configure DAOS storage and runs an IO500 benchmark
#
# Instructions that were referenced to create this script are at
# https://daosio.atlassian.net/wiki/spaces/DC/pages/11055792129/IO-500+SC21
#

set -e
trap 'echo "Hit an unexpected and unchecked error. Unmounting and exiting."; unmount' ERR

# Load needed variables
source ./configure.sh

export IO500_VERSION_TAG=io500-sc21

# Set environment variable defaults if not already set
# This allows for the variables to be set to different values externally.
: "${IO500_INSTALL_DIR:=/usr/local}"
: "${IO500_DIR:=${IO500_INSTALL_DIR}/${IO500_VERSION_TAG}}"
: "${IO500_RESULTS_DFUSE_DIR:=${HOME}/daos_fuse/${IO500_VERSION_TAG}/results}"
: "${IO500_RESULTS_DIR:=${HOME}/${IO500_VERSION_TAG}/results}"
: "${DAOS_POOL_LABEL:=io500_pool}"
: "${DAOS_CONT_LABEL:=io500_cont}"

log() {
  local msg="|  $1  |"
  line=$(printf "${msg}" | sed 's/./-/g')
  tput setaf 14 # set Cyan color
  printf -- "\n${line}\n${msg}\n${line}\n"
  tput sgr0 # reset color
}

unmount() {
  if [[ -d "${IO500_RESULTS_DFUSE_DIR}" ]]
  then
    log "Unmount DFuse mountpoint ${IO500_RESULTS_DFUSE_DIR}"
    pdsh -w ^hosts sudo fusermount3 -u "${IO500_RESULTS_DFUSE_DIR}"
    pdsh -w ^hosts rm -rf "${IO500_RESULTS_DFUSE_DIR}"
    pdsh -w ^hosts mount | sort | grep dfuse || true
    printf "\nfusermount3 complete!\n\n"
  fi
}

cleanup(){
  log "Clean up"
  if [[ -d "${IO500_RESULTS_DFUSE_DIR}" ]]
  then
    unmount
  fi
  source ./clean.sh
}

log "Prepare for IO500 ${IO500_VERSION_TAG^^} run"

log "Copy install_*.sh files to client instances"
pdcp -w ^hosts install_*.sh ~

# Install mpifileutils if not already installed
if [[ ! -d /usr/local/mpifileutils/install/bin ]]
then
  printf "\nRun install_mpifileutils.sh on client nodes\n\n"
  pdsh -w ^hosts "sudo ./install_mpifileutils.sh"
fi

# Install IO500 if not already installed
if [[ ! -d "${IO500_DIR}" ]]
then
  printf "\nRun install_${IO500_VERSION_TAG,,}.sh on client nodes\n\n"
  pdsh -w ^hosts "sudo ./install_${IO500_VERSION_TAG,,}.sh"
fi

cleanup

printf "\nCopy SSH keys to client nodes\n\n"
pdcp -w ^hosts -r .ssh ~

printf "\nCopy agent config files from server\n\n"
rm -f .ssh/known_hosts
scp ${DAOS_FIRST_SERVER}:/etc/daos/daos_agent.yml .
scp ${DAOS_FIRST_SERVER}:/etc/daos/daos_control.yml .

printf "\nConfigure DAOS Clients\n\n"
pdsh -w ^hosts rm -f .ssh/known_hosts
pdsh -w ^hosts sudo systemctl stop daos_agent
pdcp -w ^hosts daos_agent.yml daos_control.yml ~
pdsh -w ^hosts sudo cp daos_agent.yml daos_control.yml /etc/daos/
pdsh -w ^hosts sudo systemctl start daos_agent

log "Format DAOS storage"
echo "Run DAOS storage scan"
dmg -i -l ${SERVERS_LIST_WITH_COMMA} storage scan --verbose
echo "Run storage format"
dmg -i -l ${SERVERS_LIST_WITH_COMMA} storage format --reformat

printf "Waiting for DAOS storage reformat to finish"
while true
do
    if [ $(dmg -i -j system query -v | grep joined | wc -l) -eq ${DAOS_SERVER_INSTANCE_COUNT} ]
    then
        echo "Done"
        dmg -i system query -v
        break
    fi
    printf "."
    sleep 10
done

log "Query DAOS Storage"
dmg -i system query

log "Create DAOS Pool ${DAOS_POOL_SIZE}"
export DAOS_POOL_UUID=$(dmg -i -j pool create -z ${DAOS_POOL_SIZE} --name="${DAOS_POOL_LABEL}" -t 3 -u "${USER}" | jq -r .response.uuid)
echo "DAOS_POOL_UUID:" ${DAOS_POOL_UUID}

#  Show information about a created pool
log "Show DAOS Pool information"
dmg pool query --pool "${DAOS_POOL_UUID}"
#  Modify a pool's DAOS_PO_RECLAIM reclaim strategies property to never trigger aggregation
dmg -i pool set-prop --pool="${DAOS_POOL_UUID}" --name=reclaim --value=disabled

log "Create DAOS Container"
export DAOS_CONT_UUID=$(daos container create --type POSIX --pool="${DAOS_POOL_UUID}" --properties="${DAOS_CONT_REPLICATION_FACTOR}" | egrep -o '[0-9a-f-]{36}$')
echo "DAOS_CONT_UUID:" ${DAOS_CONT_UUID}

#  Show container properties
log "DAOS Container properties"
daos cont get-prop --pool=${DAOS_POOL_UUID} --cont=${DAOS_CONT_UUID}

log "Use dfuse to mount ${CONT_LABEL} on ${IO500_RESULTS_DFUSE_DIR}"
pdsh -w ^hosts sudo rm -rf "${IO500_RESULTS_DFUSE_DIR}"
pdsh -w ^hosts mkdir -p "${IO500_RESULTS_DFUSE_DIR}"
pdsh -w ^hosts dfuse --pool="${DAOS_POOL_UUID}" --container="${DAOS_CONT_UUID}" --mountpoint="${IO500_RESULTS_DFUSE_DIR}"
sleep 10
echo "DFuse complete!"

log "Load Intel MPI"
export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER="tcp;ofi_rxm"
source /opt/intel/oneapi/setvars.sh

export PATH=$PATH:${IO500_DIR}/bin
export LD_LIBRARY_PATH=/usr/local/mpifileutils/install/lib64/

log "Prepare config file for IO500"

# Set the following vars in order to do envsubst with config-full-sc21.ini
export DAOS_POOL="${DAOS_POOL_UUID}"
export DAOS_CONT="${DAOS_CONT_UUID}"
export MFU_POSIX_TS=1
export IO500_NP=$(( ${DAOS_CLIENT_INSTANCE_COUNT} * $(nproc --all) ))

cp -f "${IO500_DIR}/config-full-sc21.ini" .
envsubst < config-full-sc21.ini > temp.ini
sed -i "s|^resultdir.*|resultdir = ${IO500_RESULTS_DFUSE_DIR}|g" temp.ini
sed -i "s/^stonewall-time.*/stonewall-time = ${IO500_STONEWALL_TIME}/g" temp.ini
sed -i "s/^transferSize.*/transferSize = 4m/g" temp.ini
#sed -i "s/^blockSize.*/blockSize = 1000000m/g" temp.ini # This causes failures
sed -i "s/^filePerProc.*/filePerProc = TRUE /g" temp.ini
sed -i "s/^nproc.*/nproc = ${IO500_NP}/g" temp.ini

# Prepare final results directory for the current run
TIMESTAMP=$(date "+%Y-%m-%d_%H%M%S")
IO500_RESULTS_DIR_TIMESTAMPED="${IO500_RESULTS_DIR}/${TIMESTAMP}"
mkdir -p "${IO500_RESULTS_DIR_TIMESTAMPED}"

log "Run IO500"
mpirun -np ${IO500_NP} \
  --hostfile hosts \
  --bind-to socket "${IO500_DIR}/io500" temp.ini

log "Copy results from ${IO500_RESULTS_DFUSE_DIR} to ${IO500_RESULTS_DIR}"

rsync -avh "${IO500_RESULTS_DFUSE_DIR}/" "${IO500_RESULTS_DIR_TIMESTAMPED}/"
cp temp.ini "${IO500_RESULTS_DIR_TIMESTAMPED}/"
printenv | sort > "${IO500_RESULTS_DIR_TIMESTAMPED}/env.sh"

unmount

printf "IO500 run complete!\n\n"
printf "Results files located in "${IO500_RESULTS_DIR_TIMESTAMPED}"\n\n"
