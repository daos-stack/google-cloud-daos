#!/bin/bash

# ------------------------------------------------------------------------------
# Configure below variables to your needs
# ------------------------------------------------------------------------------
ID="maolson" # Identifier to allow multiple DAOS clusters in the same GCP
             # Typically, you want to set this to your username.
             # Don't change this value to use the env var '${USER}! It should be
             # set to a constant value.

# Server and client instances
PREEMPTIBLE_INSTANCES="true"
SSH_USER="daos-user"

# Server(s)
DAOS_SERVER_INSTANCE_COUNT="4"
DAOS_SERVER_MACHINE_TYPE=n2-highmem-32 # n2-custom-20-131072 n2-custom-40-262144 n2-highmem-32 n2-standard-2
DAOS_SERVER_DISK_COUNT=16
DAOS_SERVER_CRT_TIMEOUT=300
DAOS_SERVER_SCM_SIZE=100

# Client(s)
DAOS_CLIENT_INSTANCE_COUNT="2"
DAOS_CLIENT_MACHINE_TYPE=c2-standard-16 # c2-standard-16 n2-standard-2

# Storage
DAOS_POOL_SIZE="$(( 375 * ${DAOS_SERVER_DISK_COUNT} * ${DAOS_SERVER_INSTANCE_COUNT} / 1000 ))TB"
DAOS_CONT_REPLICATION_FACTOR="rf:0"

# IO500
IO500_STONEWALL_TIME=5      # Amount of seconds to run the benchmark


# ------------------------------------------------------------------------------
# Terraform environment variables
# It's rare that these will need to be changed.
# ------------------------------------------------------------------------------
export TF_VAR_project_id="$(gcloud info --format="value(config.project)")"
export TF_VAR_network="default"
export TF_VAR_subnetwork="default"
export TF_VAR_subnetwork_project="${TF_VAR_project_id}"
export TF_VAR_region="us-central1"
export TF_VAR_zone="us-central1-f"
export TF_VAR_preemptible="${PREEMPTIBLE_INSTANCES}"
# Servers
export TF_VAR_server_number_of_instances=${DAOS_SERVER_INSTANCE_COUNT}
export TF_VAR_server_daos_disk_count=${DAOS_SERVER_DISK_COUNT}
export TF_VAR_server_instance_base_name="daos-server-${ID}"
export TF_VAR_server_os_disk_size_gb=20
export TF_VAR_server_os_disk_type="pd-ssd"
export TF_VAR_server_template_name="daos-server-${ID}"
export TF_VAR_server_mig_name="daos-server-${ID}"
export TF_VAR_server_machine_type="${DAOS_SERVER_MACHINE_TYPE}"
export TF_VAR_server_os_project="${TF_VAR_project_id}"
export TF_VAR_server_os_family="daos-server-centos7"
# Clients
export TF_VAR_client_number_of_instances=${DAOS_CLIENT_INSTANCE_COUNT}
export TF_VAR_client_instance_base_name="daos-client-${ID}"
export TF_VAR_client_os_disk_size_gb=20
export TF_VAR_client_os_disk_type="pd-ssd"
export TF_VAR_client_template_name="daos-client-${ID}"
export TF_VAR_client_mig_name="daos-client-${ID}"
export TF_VAR_client_machine_type="${DAOS_CLIENT_MACHINE_TYPE}"
export TF_VAR_client_os_project="${TF_VAR_project_id}"
export TF_VAR_client_os_family="daos-client-centos7"


# ------------------------------------------------------------------------------
# Create hosts file
# ------------------------------------------------------------------------------

CLIENT_NAME="daos-client-${ID}"
SERVER_NAME="daos-server-${ID}"

rm -f hosts
unset CLIENTS
unset SERVERS
unset ALL_NODES

for ((i=1; i <= ${DAOS_CLIENT_INSTANCE_COUNT} ; i++))
do
    CLIENTS+="${CLIENT_NAME}-$(printf %04d ${i}) "
    echo ${CLIENT_NAME}-$(printf %04d ${i})>>hosts
done

for ((i=1; i <= ${DAOS_SERVER_INSTANCE_COUNT} ; i++))
do
    SERVERS+="${SERVER_NAME}-$(printf %04d ${i}) "
done

ALL_NODES="${SERVERS} ${CLIENTS}"
export ALL_NODES

export SERVERS
export CLIENTS

DAOS_FIRST_SERVER=$(echo ${SERVERS} | awk '{print $1}')
DAOS_FIRST_CLIENT=$(echo ${CLIENTS} | awk '{print $1}')

SERVERS_LIST_WITH_COMMA=$(echo ${SERVERS} | tr ' ' ',')
