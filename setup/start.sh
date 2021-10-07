#!/bin/bash

# Load needed variables
source ./configure.sh

# Prepare SSH key for images
if [ ! -f id_rsa -a ! -f id_rsa.pub ]
then
    ssh-keygen -t rsa -b 4096 -C "root" -N '' -f id_rsa
    cp id_rsa* ../images
fi

if [ ! -f images_were_built.flag ]
then
    echo "##########################"
    echo "#  Building DAOS images  #"
    echo "##########################"
    pushd ../images/
    ./make_images.sh
    touch ../setup/images_were_built.flag
    popd
fi

echo "######################################"
echo "#  Deploying DAOS Servers & Clients  #"
echo "######################################"

pushd ../terraform
terraform init -input=false
terraform plan -out=tfplan -input=false
terraform apply -input=false tfplan
popd

sleep 10

# Add external IP to first client, so that it will be accessible over normal SSH
gcloud compute instances add-access-config ${DAOS_FIRST_CLIENT}
sleep 10
IP=$(gcloud compute instances describe ${DAOS_FIRST_CLIENT} | grep natIP | awk '{print $2}')

# Disable OSLogin to be able to connect with SSH keys uploaded in next command
gcloud compute instances add-metadata ${DAOS_FIRST_CLIENT} --metadata enable-oslogin=FALSE
# Upload SSH key to instance, so that you could login to instance over SSH
echo "root:$(cat id_rsa.pub)" > keys.txt
gcloud compute instances add-metadata ${DAOS_FIRST_CLIENT} --metadata-from-file ssh-keys=keys.txt

# Copy files
scp -i id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    clean.sh \
    configure.sh \
    setup_io500.sh \
    "root@${IP}:~"

echo "#########################################################################"
echo "#  Now run setup_io500.sh script on ${DAOS_FIRST_CLIENT}"
echo "#  SSH to it using this command:"
echo "#  ssh -i id_rsa root@${IP}"
echo "#########################################################################"
