#!/bin/bash
# Copyright 2022 Intel Corporation
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

# PURPOSE / DESCRIPTION
#
#   Get certificates from a Secret Manager secret and copy them to /etc/daos/certs
#
#   Look for Secret Manager secret that contains the daosCA.tar.gz file.
#   The Secret Manager secret is created by Terraform but the certs are generated
#   and stored in the secret when the startup script runs on the first DAOS
#   server instance.
#
#   When the secret is found
#      1. Get the daosCA.tar.gz from the secret version data
#      2. Extract the daosCA.tar.gz to /var/daos/daosCA
#      3. Copy the cert and key files to their proper locations in /etc/daos/certs
#      4. Set ownership and permissions on certs and key files
#      3. Clean up
#
# This script only needs to be run once on each DAOS client or server instance.
# It should be called from the startup script of all DAOS client and server
# instances.
#
# In order for this script to access the secret version containing the
# daosCA.tar.gz file, the service account that is running the instance must
# be given the proper permissions on the secret. The daos_server Terraform
# module will create the secret and assign the necessary IAM
# policies to the service account so that it can access the secret.
#
# NOTE
#
#   At the time this script was written DAOS services and the dmg command
#   required that permissions on some files such as /etc/daos/certs/admin.key
#   and /etc/daos/certs/daosCA.crt files have mode 0700.  Not 0600 but 0700.
#   So when you see the odd mode, that is why it was done.

set -e
trap 'echo "An unexpected error occurred. Exiting."' ERR

SECRET_NAME="${SECRET_NAME:-$1}"    # Name of secret that was created by Terraform
INSTALL_TYPE="${INSTALL_TYPE:-$2}"  # client or server
DAOS_DIR=/var/daos
SCRIPT_NAME=$(basename "$0")

if [[ -z "${SECRET_NAME}" ]]; then
  echo "ERROR: Secret name must be passed as the first parameter. Exiting..."
  exit 1
fi

if [[ -z "${INSTALL_TYPE}" ]]; then
  echo "ERROR: Install type [client|server] must be passed as the second parameter. Exiting..."
  exit 1
fi

get_ca_from_sm() {
  # Get the daosCA.tar.gz file from Secret Manager
  # daosCA.tar.gz contains the certs that need to be copied
  # to /etc/daos/certs

  if [[ -f "${DAOS_DIR}/daosCA.tar.gz" ]]; then
    # Make sure that an old daosCA.tar.gz file doesn't exist before
    # we attempt to retrieve the file from Secret manager.
    rm -f "${DAOS_DIR}/daosCA.tar.gz"
  fi

  # Loop until the secret exists.
  # If the secret is not found in max_secret_wait_time, then exit.
  max_secret_wait_time="5 mins"
  endtime=$(date -ud "${max_secret_wait_time}" +%s)
  until gcloud secrets versions list "${SECRET_NAME}" \
    --filter="NAME:1" \
    --format="value('name')" \
    --verbosity=none | grep -q 1
  do
    if [[ $(date -u +%s) -ge ${endtime} ]]; then
      echo "ERROR: Secret '${SECRET_NAME}' not found after checking for ${max_secret_wait_time}"
      exit 1
    fi
    echo "Checking for secret: ${SECRET_NAME}"
    sleep 5
  done

  echo "Found secret: ${SECRET_NAME}"
  echo "Saving '${SECRET_NAME}' data to ${DAOS_DIR}/daosCA.tar.gz"

  # Always get version 1 of the secret. There should not be other versions.
  gcloud secrets versions access 1 --secret="${SECRET_NAME}" \
    --format "value(payload.data.decode(base64).encode(base64))" \
    | base64 --decode > "${DAOS_DIR}/daosCA.tar.gz"

  if [[ ! -f "${DAOS_DIR}/daosCA.tar.gz" ]]; then
    echo "ERROR: File not found '${DAOS_DIR}/daosCA.tar.gz'"
    exit 1
  fi

  echo "Extracting ${DAOS_DIR}/daosCA.tar.gz"
  tar xzf "${DAOS_DIR}/daosCA.tar.gz" -C "${DAOS_DIR}/"
  rm -f "${DAOS_DIR}/daosCA.tar.gz"

  # Check to make sure the directory was created before continuing
  if [[ ! -d "${DAOS_DIR}/daosCA" ]]; then
    echo "ERROR: Directory '${DAOS_DIR}/daosCA' not found. Exiting ..."
    exit 1
  fi
}

echo "BEGIN: ${SCRIPT_NAME}"

cd "${DAOS_DIR}"

# Only get the ${DAOS_DIR}/daosCA from Secret Manager
# when the ${DAOS_DIR}/daosCA directory doesn't exist.
# On the first DAOS server instance ${DAOS_DIR}/daosCA will exist because that
# is where the certs were generated. No need to get the daosCA.tar.gz file
# from the secret in that case.
if [[ ! -d "${DAOS_DIR}/daosCA" ]]; then
  get_ca_from_sm
fi

# Cleanup any old certs that may exist.
rm -rf /etc/daos/certs
mkdir -p /etc/daos/certs

echo "Copying certs and setting permissions"

# CLIENT CERTS
if [[ "${INSTALL_TYPE,,}" == "client" ]]; then
  cp ${DAOS_DIR}/daosCA/certs/daosCA.crt /etc/daos/certs/
  cp ${DAOS_DIR}/daosCA/certs/agent.* /etc/daos/certs/
  chown -R daos_agent:daos_agent /etc/daos/certs
  chmod 0755 /etc/daos/certs
  chmod 0644 /etc/daos/certs/*.crt
  chmod 0600 /etc/daos/certs/*.key
fi

# SERVER CERTS
if [[ "${INSTALL_TYPE,,}" == "server" ]]; then
  # On GCP daos_server runs as root because instances don't have IOMMU
  # So all certs and keys should be owned by root
  cp ${DAOS_DIR}/daosCA/certs/daosCA.crt /etc/daos/certs/
  cp ${DAOS_DIR}/daosCA/certs/server.* /etc/daos/certs/
  cp ${DAOS_DIR}/daosCA/certs/agent.* /etc/daos/certs/

  # Server needs a copy of the agent.crt in /etc/daos/certs/clients
  mkdir -p /etc/daos/certs/clients
  cp "${DAOS_DIR}/daosCA/certs/agent.crt" /etc/daos/certs/clients

  chown -R root:root /etc/daos/certs
  chmod 0755 /etc/daos/certs
  chmod 0755 /etc/daos/certs/clients
  chmod 0644 /etc/daos/certs/*.crt
  chmod 0600 /etc/daos/certs/*.key
  chmod 0644 /etc/daos/certs/clients/*
fi

#
# ADMIN CERTS ON CLIENTS AND SERVERS
#

# As of 2022-05-05 dmg requires mode 0700 admin.key
# Odd that its not 0600
# dmg must run as root
cp ${DAOS_DIR}/daosCA/certs/admin.* /etc/daos/certs/

chown root:root /etc/daos/certs/admin.*
chmod 0644 /etc/daos/certs/admin.crt
chmod 0700 /etc/daos/certs/admin.key

# Remove the CA dir now that the certs have been copied to /etc/daos/certs
if [[ -d "${DAOS_DIR}/daosCA" ]]; then
  rm -rf "${DAOS_DIR}/daosCA"
fi

echo "END: ${SCRIPT_NAME}"
