#!/bin/bash
#
# Install Intel OneAPI and the DAOS Client
#

set -e
trap 'echo "An unexpected error occurred. Exiting."' ERR

# DAOS_VERSION must be set before running this script
if [[ -z $DAOS_VERSION ]]; then
    echo "DAOS_VERSION not set. Exiting."
    exit 1
fi


log() {
  local msg="$1"
  printf "\n%80s" | tr " " "-"
  printf "\n%s\n" "${msg}"
  printf "%80s\n" | tr " " "-"
}


log "Cleaning yum cache and running yum update"
yum clean all
yum makecache
yum update -y

log "Installing Intel oneAPI MPI"

# Install Intel MPI from Intel oneAPI package
cat > /etc/yum.repos.d/oneAPI.repo <<EOF
[oneAPI]
name=Intel(R) oneAPI repository
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
EOF

yum install -y intel-oneapi-mpi intel-oneapi-mpi-devel

# Determine which repo to use
. /etc/os-release
OS_VERSION=$(echo "${VERSION_ID}" | cut -d. -f1)
OS_VERSION_ID="${ID,,}_${OS_VERSION}"
case ${OS_VERSION_ID} in
    centos_7)
        DAOS_OS_VERSION="CentOS7";;
    centos_8)
        DAOS_OS_VERSION="CentOS8";;
    rocky_8)
        DAOS_OS_VERSION="CentOS8";;
    *)
        printf "\nUnsupported OS: %s. Exiting\n" "${OS_VERSION_ID}"
        exit 1
        ;;
esac

log "Adding yum repo for DAOS version ${DAOS_VERSION}"
cat > /etc/yum.repos.d/daos.repo <<EOF
[daos-packages]
name=DAOS v${DAOS_VERSION} Packages
baseurl=https://packages.daos.io/v${DAOS_VERSION}/${DAOS_OS_VERSION}/packages/x86_64/
enabled=1
gpgcheck=1
protect=1
gpgkey=https://packages.daos.io/RPM-GPG-KEY
EOF

# Install DAOS client packages
log "Installing daos-client v${DAOS_VERSION}"
yum install -y daos-client daos-devel

# Install some other software helpful for development
# (e.g. to compile ior or fio)
log "Installing additional packages needed on DAOS clients"
yum install -y gcc git autoconf automake libuuid-devel devtoolset-9-gcc patch wget

log "Downgrading libfabric to 1.12 - see DAOS-9883 "
wget https://packages.daos.io/v1.2/CentOS7/packages/x86_64/libfabric-1.12.0-1.el7.x86_64.rpm
rpm -i --force ./libfabric-1.12.0-1.el7.x86_64.rpm
rpm --erase --nodeps  libfabric-1.14.0
echo "exclude=libfabric" >> /etc/yum.repos.d/daos.repo
rm -f ./libfabric-1.12.0-1.el7.x86_64.rpm

# TODO:
# - enable gvnic

printf "\nDAOS client v${DAOS_VERSION} install complete!\n\n"
