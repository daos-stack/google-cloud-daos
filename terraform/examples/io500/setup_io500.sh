#!/bin/bash

# Load needed variables
source ./configure.sh

# Clean and configure DAOS servers
source ./clean.sh

echo "Copy agent config files from server"
rm -f .ssh/known_hosts
scp ${DAOS_FIRST_SERVER}:/etc/daos/daos_agent.yml .
scp ${DAOS_FIRST_SERVER}:/etc/daos/daos_control.yml .

echo "Configure DAOS Clients"
for client in ${CLIENTS}
do
    echo "##################################################"
    echo "#  ${client}"
    echo "##################################################"
    ssh ${client} "rm -f .ssh/known_hosts"
    ssh ${client} "sudo systemctl stop daos_agent"
    scp daos_agent.yml daos_control.yml ${client}:~
    ssh ${client} "sudo cp daos_agent.yml daos_control.yml /etc/daos/"
    ssh ${client} "sudo systemctl start daos_agent"
done

echo "Format DAOS"
dmg -i -l ${SERVERS_LIST_WITH_COMMA} storage scan --verbose
dmg -i -l ${SERVERS_LIST_WITH_COMMA} storage format --reformat

echo "Wait for DAOS storage reformat to finish"
printf "Waiting"
while true
do
    if [ $(dmg -i system query -v | grep Joined | wc -l) -eq ${NUMBER_OF_SERVERS_INSTANCES} ]
    then
        echo "Done"
        dmg -i system query -v
        break
    fi
    printf "."
    sleep 10
done

echo "Create DAOS Pool ${POOL_SIZE}"
export DAOS_POOL=$(dmg -i -j pool create -z ${POOL_SIZE} -t 3 -u ${USER} | jq .response | jq -r .uuid)
echo "DAOS_POOL:" ${DAOS_POOL}
#  Show information about a created pool
dmg pool query --pool ${DAOS_POOL}
#  Modify a pool's DAOS_PO_RECLAIM reclaim strategies property to never trigger aggregation
dmg -i pool set-prop --pool ${DAOS_POOL} --name=reclaim --value=disabled

echo "Create DAOS Pool container"
export DAOS_CONT=$(daos container create --type POSIX --pool $DAOS_POOL --properties ${CONTAINER_REPLICATION_FACTOR} | egrep -o '[0-9a-f-]{36}$')
echo "DAOS_CONT:" ${DAOS_CONT}
#  Show container properties
daos cont get-prop --pool ${DAOS_POOL} --cont ${DAOS_CONT}

echo "Mount with DFuse DAOS pool to OS"
export DAOS_FUSE=${HOME}/io500/results
pdsh -w ^hosts mkdir -p ${DAOS_FUSE}
pdsh -w ^hosts dfuse --pool=${DAOS_POOL} --container=${DAOS_CONT} -m ${DAOS_FUSE}
sleep 10
echo "DFuse complete!"

echo "Export needed ENVs"
export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER="tcp;ofi_rxm"
export FI_OFI_RXM_USE_SRX=1
export FI_UNIVERSE_SIZE=1024
source /opt/intel/oneapi/setvars.sh
export PATH=$PATH:/usr/local/io500/bin
export LD_LIBRARY_PATH=/usr/local/mpifileutils/install/lib64/

echo "Prepare config file for IO500"
cp /usr/local/io500/config-full.ini .
envsubst < config-full.ini > temp.ini
sed -i "s/^stonewall-time.*/stonewall-time = ${STONEWALL_TIME}/g" temp.ini
sed -i "s/^transferSize.*/transferSize = 4m/g" temp.ini
sed -i "s/^blockSize.*/blockSize = 1000000m/g" temp.ini
sed -i "s/^filePerProc.*/filePerProc = TRUE /g" temp.ini
sed -i "s/^nproc.*/nproc = $(( ${NUMBER_OF_CLIENTS_INSTANCES} * $(nproc --all) ))/g" temp.ini

# Run IO500 benchmark
mpirun --hostfile hosts -env I_MPI_OFI_PROVIDER="tcp;ofi_rxm" --bind-to socket -np $(( ${NUMBER_OF_CLIENTS_INSTANCES} * $(nproc --all) )) /usr/local/io500/io500 temp.ini

echo "Cleaning up after run ..."
echo "Unmount DFuse mountpoint"
pdsh -w ^hosts sudo fusermount -u ${DAOS_FUSE}
echo "fusermount complete!"
echo "Delete DAOS pool"
res=$(dmg -i pool destroy --pool ${DAOS_POOL})
echo "dmg says: " $res
