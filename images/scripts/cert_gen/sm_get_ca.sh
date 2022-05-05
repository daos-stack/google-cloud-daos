
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

#
# Look for Secret Manager secret that contains the daosCA.tar.gz file.
# When the secret is found
#    1. Get the daosCA.tar.gz from the secret version data
#    2. Extract the daosCA.tar.gz to /var/daos/daosCA
#    3. Copy the cert and key files to their proper locations in /etc/daos/certs
#    4. Set ownership and permissions on certs and key files
#    3. Clean up
#
# This script only needs to be run once on each DAOS client or server instance.
#
# In order for this script to access the secret version containing the
# daosCA.tar.gz file, the service account that is running the instance must
# be given the proper permissions on the secret. Typically the secret is created
# by Terraform and therefore it is owned by the user who is running Terraform.
# The daos_server Terraform module will create the secret and apply the necessary
# policies to allow the service account to access the secret.
#

set -ue
trap 'echo "An unexpected error occurred. Exiting."' ERR

SECRET_NAME="$1"
INSTALL_TYPE="$2"  # client or server
DAOS_DIR=/var/daos

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
    # Make sure that the file doesn't exist before
    # we attempt to retrieve it from Secret manager.
    rm -f "${DAOS_DIR}/daosCA.tar.gz"
  fi

  # Loop until the secret exists.
  # Exit if secret is not found in max_secret_wait_time.
  max_secret_wait_time="5 mins"
  endtime=$(date -ud "${max_secret_wait_time}" +%s)
  until gcloud secrets list | grep -q -i ${SECRET_NAME}
  do
    if [[ $(date -u +%s) -ge ${endtime} ]]; then
      echo "ERROR: Secret '${SECRET_NAME}' was not found after checking for ${max_secret_wait_time}"
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

# TODO: Need to test without this
#       It was added when I was running into issues with missing keys on the
#       instances. The keys eventually appear on the instances with this sleep command
sleep 120

cd "${DAOS_DIR}"

# Only get the ${DAOS_DIR}/daosCA from Secret Manager
# if the ${DAOS_DIR}/daosCA directory doesn't exist.
if [[ ! -d "${DAOS_DIR}/daosCA" ]]; then
  get_ca_from_sm
fi

# Cleanup any old certs that may exist
rm -rf /etc/daos/certs
mkdir -m 0755 -p /etc/daos/certs

if [[ "${INSTALL_TYPE,,}" == "client" ]]; then
  echo "Install type is '${INSTALL_TYPE,,}'"

  cp "${DAOS_DIR}/daosCA/certs/agent.crt" /etc/daos/certs/
  chown -R daos_agent:daos_agent /etc/daos/certs/agent.crt
  chmod 0660 /etc/daos/certs/agent.crt

  cp "${DAOS_DIR}/daosCA/certs/agent.key" /etc/daos/certs/
  chown -R daos_agent:daos_agent /etc/daos/certs/agent.key
  chmod 0600 /etc/daos/certs/agent.key

  chown -R daos_agent:daos_daemons /etc/daos/certs
fi

if [[ "${INSTALL_TYPE,,}" == "server" ]]; then

  # TODO: On GCP daos_server runs as root because instances don't have IOMMU
  #       Need to investigate to be able to run as the daos_server user

  echo "Install type is '${INSTALL_TYPE,,}'. Setting permissions for root:daos_daemons"
  mkdir -m 0755 -p /etc/daos/certs/clients

  cp "${DAOS_DIR}/daosCA/certs/agent.crt" /etc/daos/certs/clients/
  chmod 0600 /etc/daos/certs/clients/agent.crt

  cp "${DAOS_DIR}/daosCA/certs/server.crt" /etc/daos/certs/
  chmod 0600 /etc/daos/certs/server.crt

  cp "${DAOS_DIR}/daosCA/certs/server.key" /etc/daos/certs/
  chmod 0600 /etc/daos/certs/server.key

  chown -R root:root /etc/daos/certs
fi

# Copy daosCA.crt to /etc/daos/certs on all DAOS server and client instances
cp "${DAOS_DIR}/daosCA/certs/daosCA.crt" /etc/daos/certs/
chown root:daos_daemons /etc/daos/certs/daosCA.crt
chmod 0644 /etc/daos/certs/daosCA.crt

# Copy admin cert to both clients and servers because we don't know
# where dmg will need to be run.
cp "${DAOS_DIR}/daosCA/certs/admin.crt" /etc/daos/certs/
chown root:daos_daemons /etc/daos/certs/admin.crt
chmod 0644 /etc/daos/certs/admin.crt

cp "${DAOS_DIR}/daosCA/certs/admin.key" /etc/daos/certs/
chown root:daos_daemons /etc/daos/certs/admin.key
chmod 0640 /etc/daos/certs/admin.key

# Remove the CA dir now that the certs have been copied to /etc/daos/certs
if [[ -d "${DAOS_DIR}/daosCA" ]]; then
  rm -rf "${DAOS_DIR}/daosCA"
fi
