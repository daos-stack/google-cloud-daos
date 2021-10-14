#!/bin/bash

# Load needed variables
source ./configure.sh

echo "####################################"
echo "#  Destroying DAOS Servers & Clients"
echo "####################################"

pushd ../full_cluster_setup
terraform destroy -auto-approve
popd
