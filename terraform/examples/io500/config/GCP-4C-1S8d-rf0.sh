#!/usr/bin/env bash
# Copyright 2023 Intel Corporation
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

# shellcheck disable=SC2034,SC2155

# ------------------------------------------------------------------------------
# Configuration: 4 clients, 1 server, 8 disks per server
# IO500 Config:  io500-sc23.config-template.daos-rf0.ini
# ------------------------------------------------------------------------------

# Set if you want to prepend a string to the names of the instances
: "${RESOURCE_PREFIX:=}"

# Server and client instances
DAOS_SSH_USER="daos-user"
DAOS_ALLOW_INSECURE="false"
DAOS_SOURCE_IMAGE_FAMILY="hpc-rocky-linux-8"
DAOS_SOURCE_IMAGE_PROJECT_ID="cloud-hpc-image-public"

# Server(s)
DAOS_SERVER_INSTANCE_COUNT="1"
DAOS_SERVER_MACHINE_TYPE=n2-custom-36-262144
DAOS_SERVER_DISK_COUNT=8
DAOS_SERVER_CRT_TIMEOUT=300
DAOS_SERVER_GVNIC=false
DAOS_SERVER_IMAGE_FAMILY="daos-server-io500-hpc-rocky-8"

# Client(s)
DAOS_CLIENT_INSTANCE_COUNT="4"
DAOS_CLIENT_MACHINE_TYPE=c2-standard-16
DAOS_CLIENT_GVNIC=false
DAOS_CLIENT_IMAGE_FAMILY="daos-client-io500-hpc-rocky-8"

# Storage
DAOS_POOL_SIZE="100%"
DAOS_CONT_REPLICATION_FACTOR="rf:0"
DAOS_CHUNK_SIZE="1048576" # 1MB

# IO500
IO500_TEST_CONFIG_ID="GCP-4C-1S8d-rf0"
IO500_STONEWALL_TIME=60 # Number of seconds to run the benchmark
IO500_INI="io500-sc23.config-template.daos-rf0.ini"

# GCP
GCP_PROJECT_ID=$(gcloud info --format="value(config.project)")
GCP_REGION="us-central1"
GCP_ZONE="us-central1-f"
GCP_NETWORK_NAME="default"
GCP_SUBNETWORK_NAME="default"
