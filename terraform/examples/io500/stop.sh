#!/bin/bash

set -e
trap 'echo "Hit an unexpected and unchecked error. Exiting."' ERR

# Load needed variables
source ./configure.sh

echo "####################################"
echo "#  Destroying DAOS Servers & Clients"
echo "####################################"

pushd ../full_cluster_setup
terraform destroy -auto-approve
popd
