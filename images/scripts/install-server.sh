#!/bin/bash
#
# Install DAOS Server
#

set -e
trap 'echo "An unexpected error occurred. Exiting."' ERR

# DAOS_VERSION must be set before running this script
if [ -z "$DAOS_VERSION" ];then
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

# Determine which official DAOS repo to use
# Offical DAOS repos are located at https://packages.daos.io/
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

log "Installing stackdriver-agent"
curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh
bash add-monitoring-agent-repo.sh
yum install -y stackdriver-agent

log "Installing daos-server v${DAOS_VERSION}"
yum install -y daos-server

log "Downgrading libfabric to 1.12 - see DAOS-9883 "
yum install -y wget
wget https://packages.daos.io/v1.2/CentOS7/packages/x86_64/libfabric-1.12.0-1.el7.x86_64.rpm
rpm -i --force ./libfabric-1.12.0-1.el7.x86_64.rpm
rpm --erase --nodeps  libfabric-1.14.0
echo "exclude=libfabric" >> /etc/yum.repos.d/daos.repo
rm -f ./libfabric-1.12.0-1.el7.x86_64.rpm

# TODO:
# - enable gvnic

printf "\nDAOS server v${DAOS_VERSION} install complete!\n\n"
