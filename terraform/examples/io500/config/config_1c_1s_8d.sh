#!/bin/bash

# ------------------------------------------------------------------------------
# Configuration: 1 client, 1 server with 8 disks
# ------------------------------------------------------------------------------
# Optional identifier to allow multiple DAOS clusters in the same GCP
# project by using this ID in the DAOS server and client instance names.
# Typically, this would contain the username of each user who is running
# the terraform/examples/io500/start.sh script in one GCP project.
# This should be set to a constant value and not the value of an
# environment variable such as '${USER}' which changes depending on where this
# file gets sourced.
ID=""

# Server and client instances
PREEMPTIBLE_INSTANCES="true"
SSH_USER="daos-user"

# Server(s)
DAOS_SERVER_INSTANCE_COUNT="1"
DAOS_SERVER_MACHINE_TYPE=n2-highmem-32
DAOS_SERVER_DISK_COUNT=8
DAOS_SERVER_CRT_TIMEOUT=300
DAOS_SERVER_SCM_SIZE=100

# Client(s)
DAOS_CLIENT_INSTANCE_COUNT="1"
DAOS_CLIENT_MACHINE_TYPE=c2-standard-16

# Storage
DAOS_POOL_SIZE="$(( 375 * ${DAOS_SERVER_DISK_COUNT} * ${DAOS_SERVER_INSTANCE_COUNT} / 1000 ))TB"
DAOS_CONT_REPLICATION_FACTOR="rf:0"

# IO500
IO500_STONEWALL_TIME=5  # Number of seconds to run the benchmark

# ------------------------------------------------------------------------------
# Modify instance base names if ID variable is set
# ------------------------------------------------------------------------------
DAOS_CONFIG_NAME="${DAOS_CLIENT_INSTANCE_COUNT}c-${DAOS_SERVER_INSTANCE_COUNT}s-${DAOS_SERVER_DISK_COUNT}d"
DAOS_SERVER_BASE_NAME="${DAOS_SERVER_BASE_NAME:-daos-server-${DAOS_CONFIG_NAME}}"
DAOS_CLIENT_BASE_NAME="${DAOS_CLIENT_BASE_NAME:-daos-client-${DAOS_CONFIG_NAME}}"
if [[ -n ${ID} ]]; then
    DAOS_SERVER_BASE_NAME="${DAOS_SERVER_BASE_NAME}-${ID}"
    DAOS_CLIENT_BASE_NAME="${DAOS_CLIENT_BASE_NAME}-${ID}"
fi

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
export TF_VAR_server_instance_base_name="${DAOS_SERVER_BASE_NAME}"
export TF_VAR_server_os_disk_size_gb=20
export TF_VAR_server_os_disk_type="pd-ssd"
export TF_VAR_server_template_name="${DAOS_SERVER_BASE_NAME}"
export TF_VAR_server_mig_name="${DAOS_SERVER_BASE_NAME}"
export TF_VAR_server_machine_type="${DAOS_SERVER_MACHINE_TYPE}"
export TF_VAR_server_os_project="${TF_VAR_project_id}"
export TF_VAR_server_os_family="daos-server-io500-centos-7"
# Clients
export TF_VAR_client_number_of_instances=${DAOS_CLIENT_INSTANCE_COUNT}
export TF_VAR_client_instance_base_name="${DAOS_CLIENT_BASE_NAME}"
export TF_VAR_client_os_disk_size_gb=20
export TF_VAR_client_os_disk_type="pd-ssd"
export TF_VAR_client_template_name="${DAOS_CLIENT_BASE_NAME}"
export TF_VAR_client_mig_name="${DAOS_CLIENT_BASE_NAME}"
export TF_VAR_client_machine_type="${DAOS_CLIENT_MACHINE_TYPE}"
export TF_VAR_client_os_project="${TF_VAR_project_id}"
export TF_VAR_client_os_family="daos-client-io500-hpc-centos-7"
