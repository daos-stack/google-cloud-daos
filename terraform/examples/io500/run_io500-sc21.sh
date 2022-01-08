#!/bin/bash
#
# Configure DAOS storage and runs an IO500 benchmark
#

set -e

# Load needed variables
source ./configure.sh

IO500_VERSION_TAG=io500-sc21

# Set environment variable defaults if not already set
# This allows for the variables to be set to different values externally.
: "${IO500_INSTALL_DIR:=/usr/local}"
: "${IO500_DIR:=${IO500_INSTALL_DIR}/${IO500_VERSION_TAG}}"
: "${IO500_RESULTS_DIR:=${HOME}/${IO500_VERSION_TAG}/results}"
: "${POOL_LABEL:=io500_pool}"
: "${CONT_LABEL:=io500_cont}"

log() {
  local msg="$1"
  printf "\n%80s" | tr " " "-"
  printf "\n%s\n" "${msg}"
  printf "%80s\n" | tr " " "-"
}

cleanup(){
  if [[ ! -z $1 ]];then
    echo "Hit an unexpected and unchecked error. Cleaning up and exiting."
  fi

  log "Clean up"
  if [[ -d "${IO500_RESULTS_DIR}" ]];then
    echo "Unmount DFuse mountpoint ${IO500_RESULTS_DIR}"
    pdsh -w ^hosts sudo fusermount -u "${IO500_RESULTS_DIR}"
    echo "fusermount complete!"
  fi
  source ./clean.sh
}

#trap cleanup ERR

log "Prepare for IO500 ${IO500_VERSION_TAG^^} run"

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

log "Create pool: label=${POOL_LABEL} size=${DAOS_POOL_SIZE}"
dmg -i pool create -z ${DAOS_POOL_SIZE} -t 3 -u ${USER} --label=${POOL_LABEL}
echo "Set pool property: reclaim=disabled"
dmg -i pool set-prop ${POOL_LABEL} --name=reclaim --value=disabled
echo "Pool created successfully"
dmg pool query "${POOL_LABEL}"

log "Create container: label=${CONT_LABEL}"
daos container create --type=POSIX --properties="${DAOS_CONT_REPLICATION_FACTOR}" --label="${CONT_LABEL}" "${POOL_LABEL}"
#export DAOS_CONT_UUID=$(daos -j container create --type=POSIX --properties="${DAOS_CONT_REPLICATION_FACTOR}" --label="${CONT_LABEL}" "${POOL_LABEL}" | jq -r .response.container_uuid)
#echo "DAOS_CONT_UUID:" ${DAOS_CONT_UUID}
#  Show container properties
daos cont get-prop ${POOL_LABEL} ${CONT_LABEL}

export IO500_RESULTS_DIR="${HOME}/io500-${IO500_VERSION_TAG}/results"
pdsh -w ^hosts mkdir -p "${IO500_RESULTS_DIR}"

log "Use dfuse to mount ${CONT_LABEL} on ${IO500_RESULTS_DIR}"
pdsh -w ^hosts sudo rm -rf "${IO500_RESULTS_DIR}"
pdsh -w ^hosts mkdir -p "${IO500_RESULTS_DIR}"
pdsh -w ^hosts dfuse --pool="${POOL_LABEL}" --container="${CONT_LABEL}" --mountpoint="${IO500_RESULTS_DIR}"
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
export DAOS_POOL="${POOL_LABEL}"
export DAOS_CONT="${CONT_LABEL}"
export MFU_POSIX_TS=1
export IO500_NP=$(( ${DAOS_CLIENT_INSTANCE_COUNT} * $(nproc --all) ))

cp -f "${IO500_DIR}/config-full-sc21.ini" .
envsubst < config-full-sc21.ini > temp.ini
sed -i "s|^resultdir.*|resultdir = ${IO500_RESULTS_DIR}|g" temp.ini
sed -i "s/^stonewall-time.*/stonewall-time = ${IO500_STONEWALL_TIME}/g" temp.ini
sed -i "s/^transferSize.*/transferSize = 4m/g" temp.ini
#sed -i "s/^blockSize.*/blockSize = 1000000m/g" temp.ini # This causes failures
sed -i "s/^filePerProc.*/filePerProc = TRUE /g" temp.ini
sed -i "s/^nproc.*/nproc = ${IO500_NP}/g" temp.ini

log "Run IO500"
mpirun -np ${IO500_NP} \
  --hostfile hosts \
  --bind-to socket "${IO500_DIR}/io500" temp.ini

cleanup

printf "\nIO500 DONE!\n\n"
