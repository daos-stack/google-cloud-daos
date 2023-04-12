#!/usr/bin/env bash

set -eo pipefail
trap 'echo "Unexpected and unchecked error. Exiting."' ERR

: "${DAOS_VERSION:="2.2.0"}"
: "${DAOS_REPO_BASE_URL:="https://packages.daos.io"}"
: "${GCP_PROJECT:=""}"
: "${GCP_ZONE:=""}"
: "${GCP_BUILD_WORKER_POOL:=""}"
: "${GCP_USE_IAP:=true}"
: "${GCP_ENABLE_OSLOGIN:=false}"
: "${GCP_USE_CLOUDBUILD:=true}"
: "${GCP_CONFIGURE_PROJECT:=true}" # Set service account and iam roles for cloud build
: "${DAOS_MACHINE_TYPE:="n2-standard-32"}"
: "${DAOS_SOURCE_IMAGE_FAMILY:="rocky-linux-8-optimized-gcp"}"
: "${DAOS_SOURCE_IMAGE_PROJECT_ID:="rocky-linux-cloud"}"
: "${DAOS_SERVER_IMAGE_FAMILY:="daos-server-rocky-8"}"
: "${DAOS_CLIENT_IMAGE_FAMILY:="daos-client-rocky-8"}"
: "${DAOS_BUILD_SERVER_IMAGE:=true}"
: "${DAOS_BUILD_CLIENT_IMAGE:=true}"
: "${DAOS_PACKER_TEMPLATE:="daos_image.pkr.hcl"}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
START_TIMESTAMP="${START_TIMESTAMP:-$(date "+%FT%T")}"

# BEGIN: Logging variables and functions
declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4 [OFF]=5)
declare -A LOG_COLORS=([DEBUG]=2 [INFO]=12 [WARN]=3 [ERROR]=1 [FATAL]=9 [OFF]=0 [OTHER]=15)
LOG_LEVEL=DEBUG

log() {
  local msg="$1"
  local lvl=${2:-INFO}
  if [[ ${LOG_LEVELS[$LOG_LEVEL]} -le ${LOG_LEVELS[$lvl]} ]]; then
    if [[ -t 1 ]]; then tput setaf "${LOG_COLORS[$lvl]}"; fi
    printf "[%-5s] %s\n" "$lvl" "${msg}" 1>&2
    if [[ -t 1 ]]; then tput sgr0; fi
  fi
}

log.debug() { log "${1}" "DEBUG"; }
log.info() { log "${1}" "INFO"; }
log.warn() { log "${1}" "WARN"; }
log.error() { log "${1}" "ERROR"; }
log.fatal() { log "${1}" "FATAL"; }
# END: Logging variables and functions

verify_gcloud() {
  if ! gcloud -v &>/dev/null; then
    log.error "gcloud not found
        Is the Google Cloud Platform SDK installed?
        See https://cloud.google.com/sdk/docs/install"
    exit 1
  fi
}

init() {
  if [ -z "$GCP_PROJECT" ]; then
    verify_gcloud
    GCP_PROJECT=$(gcloud config list --format='value(core.project)')
    if [ -z "$GCP_PROJECT" ]; then
      log.error "Unable to set GCP_PROJECT from active gcloud configuration"
      exit 1
    fi
  fi

  if [ -z "$GCP_ZONE" ]; then
    verify_gcloud
    GCP_ZONE=$(gcloud config list --format='value(compute.zone)')
    if [ -z "$GCP_PROJECT" ]; then
      log.error "Unable to set GCP_PROJECT from active gcloud configuration"
      exit 1
    fi
  fi
}

create_pkrvars_file() {
  cat >"${SCRIPT_DIR}/daos_image.pkrvars.hcl" <<EOF
daos_version="${DAOS_VERSION}"
daos_repo_base_url="${DAOS_REPO_BASE_URL}"
project_id="${GCP_PROJECT}"
zone="${GCP_ZONE}"
use_iap="${GCP_USE_IAP}"
enable_oslogin="${GCP_ENABLE_OSLOGIN}"
machine_type="${DAOS_MACHINE_TYPE}"
source_image_family="${DAOS_SOURCE_IMAGE_FAMILY}"
source_image_project_id="${DAOS_SOURCE_IMAGE_PROJECT_ID}"
image_guest_os_features=["GVNIC"]
disk_size="20"
state_timeout="10m"
scopes=["https://www.googleapis.com/auth/cloud-platform"]
use_internal_ip=true
omit_external_ip=false
daos_install_type="${DAOS_INSTALL_TYPE}"
image_family="${IMAGE_FAMILY}"
EOF
}

cleanup_pkrvars_file() {
  local vars_file="${SCRIPT_DIR}/daos_image.pkrvars.hcl"
  if [[ -f "${vars_file}" ]]; then
    rm -f "${vars_file}"
  fi
}

run_packer() {
  packer init -var-file=daos_image.pkrvars.hcl daos_image.pkr.hcl
  packer build -var-file=daos_image.pkrvars.hcl daos_image.pkr.hcl
}

configure_gcp_project() {

  [[ "${GCP_CONFIGURE_PROJECT}" == "false" ]] && return

  # The service account used here should have been already created
  # by the "packer_build" step.  We are just checking here.
  CLOUD_BUILD_ACCOUNT=$(gcloud projects get-iam-policy "${GCP_PROJECT}" \
    --filter="(bindings.role:roles/cloudbuild.builds.builder)" \
    --flatten="bindings[].members" \
    --format="value(bindings.members[])" \
    --limit=1)
  log.info "Packer will be using service account ${CLOUD_BUILD_ACCOUNT} in the Cloud Build job"

  # Add cloudbuild SA permissions
  CHECK_ROLE_INST_ADMIN=$(
    gcloud projects get-iam-policy "${GCP_PROJECT}" \
      --flatten="bindings[].members" \
      --filter="bindings.role=roles/compute.instanceAdmin.v1 AND \
              bindings.members=${CLOUD_BUILD_ACCOUNT}" \
      --format="value(bindings.members[])"
  )
  if [[ "${CHECK_ROLE_INST_ADMIN}" != "${CLOUD_BUILD_ACCOUNT}" ]]; then
    gcloud projects add-iam-policy-binding "${GCP_PROJECT}" \
      --member "${CLOUD_BUILD_ACCOUNT}" \
      --role roles/compute.instanceAdmin.v1
  fi

  CHECK_ROLE_SVC_ACCT=$(
    gcloud projects get-iam-policy "${GCP_PROJECT}" \
      --flatten="bindings[].members" \
      --filter="bindings.role=roles/iam.serviceAccountUser AND \
              bindings.members=${CLOUD_BUILD_ACCOUNT}" \
      --format="value(bindings.members[])"
  )
  if [[ "${CHECK_ROLE_SVC_ACCT}" != "${CLOUD_BUILD_ACCOUNT}" ]]; then
    gcloud projects add-iam-policy-binding "${GCP_PROJECT}" \
      --member "${CLOUD_BUILD_ACCOUNT}" \
      --role roles/iam.serviceAccountUser
  fi

  CHECK_ROLE_IAP_TUNL_RESR_ACCS=$(
    gcloud projects get-iam-policy "${GCP_PROJECT}" \
      --flatten="bindings[].members" \
      --filter="bindings.role=roles/iap.tunnelResourceAccessor AND \
              bindings.members=${CLOUD_BUILD_ACCOUNT}" \
      --format="value(bindings.members[])"
  )
  if [[ "${CHECK_ROLE_IAP_TUNL_RESR_ACCS}" != "${CLOUD_BUILD_ACCOUNT}" ]]; then
    gcloud projects add-iam-policy-binding "${GCP_PROJECT}" \
      --member "${CLOUD_BUILD_ACCOUNT}" \
      --role roles/iap.tunnelResourceAccessor
  fi
}

submit_build() {
  DAOS_PACKER_TEMPLATE="daos_image.pkr.hcl"
  BUILD_OPTIONAL_ARGS=""

  configure_gcp_project

  if [[ -z "${GCP_BUILD_WORKER_POOL}" ]]; then
    # When worker pool is specified then region needs to match the one of the pool.
    # Need to parse the correct region to use it instead of the default one "global".
    # Format: projects/{project}/locations/{region}/workerPools/{workerPool}
    local locations="${GCP_BUILD_WORKER_POOL#*locations/}"
    BUILD_REGION="${locations%%/*}"
    BUILD_OPTIONAL_ARGS+=" --worker-pool=${GCP_BUILD_WORKER_POOL}"
    echo "Using build worker pool ${GCP_BUILD_WORKER_POOL}, region ${BUILD_REGION}"
  fi

  if [[ -z "${BUILD_REGION}" ]]; then
    BUILD_OPTIONAL_ARGS+=" --region=${BUILD_REGION}"
  fi

  # shellcheck disable=SC2086
  gcloud builds submit --timeout=1800s \
    --substitutions="_PACKER_TEMPLATE=${DAOS_PACKER_TEMPLATE}" \
    --config=packer_cloudbuild.yaml ${BUILD_OPTIONAL_ARGS} .
}

build_image() {
  DAOS_INSTALL_TYPE="$1"
  IMAGE_FAMILY="$2"
  log.info "Building DAOS ${DAOS_INSTALL_TYPE} image: ${IMAGE_FAMILY}"
  cd "${SCRIPT_DIR}"
  create_pkrvars_file
  if [[ "${GCP_USE_CLOUDBUILD}" == "true" ]]; then
    submit_build
  else
    run_packer
  fi
  cleanup_pkrvars_file
}

build_server_image() {
  [[ "${DAOS_BUILD_SERVER_IMAGE}" == "false" ]] && return
  build_image "server" "${DAOS_SERVER_IMAGE_FAMILY}"
}

build_client_image() {
  [[ "${DAOS_BUILD_CLIENT_IMAGE}" == "false" ]] && return
  build_image "client" "${DAOS_CLIENT_IMAGE_FAMILY}"
}

list_images() {
  log.info "Image(s) created"
  gcloud compute images list \
    --project="${GCP_PROJECT}" \
    --filter="creationTimestamp>=${START_TIMESTAMP}" \
    --format="table(name,family,creationTimestamp)" \
    --sort-by="creationTimestamp"
}

main() {
  init
  build_server_image
  build_client_image
  list_images
}

main
