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
# Configuration: 32 clients, 10 servers, 16 disks per server
# IO500 Config:  io500-sc22.config-template.daos-rf2.ini
# ------------------------------------------------------------------------------
# Set if you want to prepend a string to the names of the instances
: "${RESOURCE_PREFIX:=}"

# Server and client instances
DAOS_SSH_USER="daos-user"
DAOS_ALLOW_INSECURE="false"
DAOS_SOURCE_IMAGE_FAMILY="rocky-linux-8-optimized-gcp"
DAOS_SOURCE_IMAGE_PROJECT_ID="rocky-linux-cloud"

# Server(s)
DAOS_SERVER_INSTANCE_COUNT="10"
DAOS_SERVER_MACHINE_TYPE=n2-custom-36-262144
DAOS_SERVER_DISK_COUNT=16
DAOS_SERVER_CRT_TIMEOUT=300
DAOS_SERVER_SCM_SIZE=200
DAOS_SERVER_GVNIC=false
DAOS_SERVER_IMAGE_FAMILY="daos-server-io500-rocky-8"

# Client(s)
DAOS_CLIENT_INSTANCE_COUNT="32"
DAOS_CLIENT_MACHINE_TYPE=c2-standard-16
DAOS_CLIENT_GVNIC=false
DAOS_CLIENT_IMAGE_FAMILY="daos-client-io500-rocky-8"

# Storage
DAOS_POOL_SIZE="$(awk -v disk_count=${DAOS_SERVER_DISK_COUNT} -v server_count=${DAOS_SERVER_INSTANCE_COUNT} 'BEGIN {pool_size = 375 * disk_count * server_count / 1000; print pool_size"TB"}')"
DAOS_CONT_REPLICATION_FACTOR="rf:2"

# IO500
IO500_TEST_CONFIG_ID="GCP-32C-10S16d-rf2"
IO500_STONEWALL_TIME=60 # Number of seconds to run the benchmark
IO500_INI="io500-sc22.config-template.daos-rf2.ini"

# GCP
GCP_PROJECT_ID=$(gcloud info --format="value(config.project)")
GCP_REGION="us-central1"
GCP_ZONE="us-central1-f"
GCP_NETWORK_NAME="default"
GCP_SUBNETWORK_NAME="default"
