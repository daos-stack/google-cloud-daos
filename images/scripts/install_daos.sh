#!/bin/bash
#
# Install DAOS Server or Client packages
#

set -e
trap 'echo "An unexpected error occurred. Exiting."' ERR

SCRIPT_NAME=$(basename "$0")
DAOS_REPO_BASE_URL="${DAOS_REPO_BASE_URL:-https://packages.daos.io}"

show_help() {
  cat <<EOF
Usage:

  ${SCRIPT_NAME} <options>

  Install the DAOS server or client

Options:

  -t --type     DAOS_INSTALL_TYPE        Installation Type
                                         Valid values [ all | client | server ]

  -v --version  DAOS_VERSION              Version of DAOS to install

  [-u --repo-baseurl DAOS_REPO_BASE_URL ] Base URL of a repo

  [ -h --help ]                           Show help

Examples:

  Install daos-client

    ${SCRIPT_NAME} -t client

  Install daos-server

    ${SCRIPT_NAME} -t server

EOF
}

log() {
  # shellcheck disable=SC2155,SC2183
  local line=$(printf "%80s" | tr " " "-")
  if [[ -t 1 ]]; then tput setaf 14; fi
  printf -- "\n%s\n %-78s \n%s\n" "${line}" "${1}" "${line}"
  if [[ -t 1 ]]; then tput sgr0; fi
}

log_error() {
  # shellcheck disable=SC2155,SC2183
  if [[ -t 1 ]]; then tput setaf 160; fi
  printf -- "\n%s\n\n" "${1}" >&2;
  if [[ -t 1 ]]; then tput sgr0; fi
}

opts() {
  # shift will cause the script to exit if attempting to shift beyond the
  # max args.  So set +e to continue processing when shift errors.
  set +e
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type|-t)
        DAOS_INSTALL_TYPE="$2"
        if [[ "${DAOS_INSTALL_TYPE}" == -* ]] || [[ "${DAOS_INSTALL_TYPE}" = "" ]] || [[ -z ${DAOS_INSTALL_TYPE} ]]; then
          log_error "ERROR: Missing INSTALL_TYPE value for -t or --type"
          show_help
          exit 1
        elif [[ ! "${DAOS_INSTALL_TYPE}" =~ ^(all|server|client)$ ]]; then
          log_error "ERROR: Invalid value '${DAOS_INSTALL_TYPE}' for INSTALL_TYPE"
          log_error "       Valid values are 'all', 'server', 'client'"
          show_help
          exit 1
        fi
        shift 2
      ;;
      --version|-v)
        DAOS_VERSION="${2}"
        if [[ "${DAOS_VERSION}" == -* ]] || [[ "${DAOS_VERSION}" = "" ]] || [[ -z ${DAOS_VERSION} ]]; then
          log_error "ERROR: Missing VERSION value for -v or --version"
          show_help
          exit 1
        else
          # Verify that it looks like a version number
          if ! echo "${DAOS_VERSION}" | grep -q -E "([0-9]{1,}\.)+[0-9]{1,}"; then
            log_error "ERROR: Value '${DAOS_VERSION}' for -v or --version does not appear to be a valid version"
            show_help
            exit 1
          fi
        fi
        shift 2
      ;;
      --repo-baseurl|-u)
        DAOS_REPO_BASE_URL="${2}"
        if [[ "${DAOS_REPO_BASE_URL}" == -* ]] || [[ "${DAOS_REPO_BASE_URL}" = "" ]] || [[ -z ${DAOS_REPO_BASE_URL} ]]; then
          log_error "ERROR: Missing URL value for --repo-baseurl"
          show_help
          exit 1
        fi
        shift 2
      ;;
      --help|-h)
        show_help
        exit 0
      ;;
      --)
        break
      ;;
	    --*|-*)
        log_error "ERROR: Unrecognized option '${1}'"
        show_help
        exit 1
      ;;
	    *)
        log_error "ERROR: Unrecognized option '${1}'"
        shift
        break
      ;;
    esac
  done
  set -e

  if [[ -z ${DAOS_INSTALL_TYPE} ]]; then
    log_error "ERROR: -t INSTALL_TYPE required"
    show_help
    exit 1
  fi

  if [[ -z ${DAOS_VERSION} ]]; then
    log_error "ERROR: -v VERSION required"
    show_help
    exit 1
  fi

  export DAOS_INSTALL_TYPE
  export DAOS_VERSION
  export DAOS_REPO_BASE_URL

}

verify_version(){
  # Check to make sure the version exists
  local status_code=""
  status_code=$(curl -s -o /dev/null -w "%{http_code}" "${DAOS_REPO_BASE_URL}/v${DAOS_VERSION}")
  if [[ ! "${status_code}" =~ ^(200|301|302)$ ]]; then
    log_error "ERROR: DAOS version '${DAOS_VERSION}' not found at ${DAOS_REPO_BASE_URL}/v${DAOS_VERSION}"
    exit 1
  fi
}

preinstall_check() {
  if rpm -qa | grep -q "daos-${DAOS_INSTALL_TYPE,,}-${DAOS_VERSION}"; then
    echo "daos-${DAOS_INSTALL_TYPE,,} ${DAOS_VERSION} already installed. Exiting."
    exit 0
  fi
}

add_repo() {
  # Determine which repo to use
  # shellcheck disable=SC1091
  source "/etc/os-release"
  OS_VERSION=$(echo "${VERSION_ID}" | cut -d. -f1)
  OS_VERSION_ID="${ID,,}_${OS_VERSION}"
  case ${OS_VERSION_ID} in
    centos_7)
      DAOS_OS_VERSION="CentOS7"
      ;;
    centos_8)
      DAOS_OS_VERSION="CentOS8"
      ;;
    rocky_8)
      DAOS_OS_VERSION="CentOS8"
      ;;
    *)
      log_error "ERROR: Unsupported OS: ${OS_VERSION_ID}. Exiting."
      exit 1
      ;;
  esac

  echo "Adding DAOS v${DAOS_VERSION} packages repo"
  curl -s --output /etc/yum.repos.d/daos_packages.repo "https://packages.daos.io/v${DAOS_VERSION}/${DAOS_OS_VERSION}/packages/x86_64/daos_packages.repo"

}

install_epel() {
  # DAOS has dependencies on packages in epel
  if ! rpm -qa | grep -q "epel-release"; then
    yum install -y epel-release
  fi
}

install_daos() {
  if [[ "${DAOS_INSTALL_TYPE,,}" =~ ^(all|client)$ ]]; then
    echo "Install daos-client and daos-devel packages"
    yum install -y daos-client daos-devel
  fi

  if [[ "${DAOS_INSTALL_TYPE,,}" =~ ^(all|server)$ ]]; then
    echo "Install daos-server and client packages"
    yum install -y daos-server daos-client
  fi

  if echo "${DAOS_VERSION}" | grep -q -e '^1\..*'; then
    # Upgrade SPDK to work around the GCP NVMe bug with number of qpairs
    # in DAOS v1.2
    yum install -y wget
    TMP_DIR="$(mktemp -d)"
    pushd .
    cd "${TMP_DIR}"
    wget "https://packages.daos.io/v${DAOS_VERSION}/CentOS7/spdk/x86_64/spdk-20.01.2-2.el7.x86_64.rpm"
    wget "https://packages.daos.io/v${DAOS_VERSION}/CentOS7/spdk/x86_64/spdk-tools-20.01.2-2.el7.noarch.rpm"
    rpm -Uvh ./spdk-20.01.2-2.el7.x86_64.rpm ./spdk-tools-20.01.2-2.el7.noarch.rpm
    rm -r "${TMP_DIR}"
  fi
}

downgrade_libfabric() {
  if [[ ${DAOS_VERSION%%.*} == "2" ]]; then
    log "Downgrading libfabric to v1.12 - see https://daosio.atlassian.net/browse/DAOS-9883"
    wget https://packages.daos.io/v1.2/CentOS7/packages/x86_64/libfabric-1.12.0-1.el7.x86_64.rpm
    rpm -i --force ./libfabric-1.12.0-1.el7.x86_64.rpm
    rpm --erase --nodeps  libfabric-1.14.0
    echo "exclude=libfabric" >> /etc/yum.repos.d/daos.repo
    rm -f ./libfabric-1.12.0-1.el7.x86_64.rpm
  fi
}

install_additional_pkgs() {
  yum install -y clustershell curl git jq patch pdsh rsync wget
}

main() {
  opts "$@"
  log "Installing DAOS v${DAOS_VERSION}"
  preinstall_check
  verify_version
  add_repo
  install_epel
  install_additional_pkgs
  install_daos
  downgrade_libfabric
  printf "\n%s\n\n" "DONE! DAOS v${DAOS_VERSION} installed"
}

main "$@"
