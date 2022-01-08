#!/bin/bash

set -e
trap 'echo "Hit an unexpected and unchecked error. Exiting."' ERR

# Load needed variables
source ./configure.sh

for server in ${SERVERS}
do
    printf "\nStart cleaning ${server}\n\n"
    ssh ${server} "rm -f .ssh/known_hosts"
    ssh ${server} "sudo systemctl stop daos_server"
    ssh ${server} "sudo rm -rf /var/daos/ram/*"
    ssh ${server} "sudo umount /var/daos/ram/ && echo success || echo unmounted"
    ssh ${server} "sudo sed -i \"s/^crt_timeout:.*/crt_timeout: ${DAOS_SERVER_CRT_TIMEOUT}/g\" /etc/daos/daos_server.yml"
    ssh ${server} "sudo sed -i \"s/^   targets:.*/   targets: ${DAOS_SERVER_DISK_COUNT}/g\" /etc/daos/daos_server.yml"
    ssh ${server} "sudo sed -i \"s/^   scm_size:.*/   scm_size: ${DAOS_SERVER_SCM_SIZE}/g\" /etc/daos/daos_server.yml"
    ssh ${server} "cat /etc/daos/daos_server.yml"
    ssh ${server} "sudo systemctl start daos_server"
    sleep 4
    ssh ${server} "sudo systemctl status daos_server"
    printf "\nFinished cleaning ${server}\n\n"
done
