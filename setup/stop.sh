#!/bin/bash

# Load needed variables
source ./configure.sh

echo "####################################"
echo "#  Destroying DAOS Servers & Clients"
echo "####################################"

pushd ../terraform
terraform destroy -auto-approve
popd
