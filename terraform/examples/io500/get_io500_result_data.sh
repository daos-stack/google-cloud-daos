#!/usr/bin/env bash
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
# Get the IO500 result data from the first client node in a cluster after
# the run_io500-sc22.sh script has finished running.
# Log out of the client and then in your cloud shell or local system
# run ./get_io500_result_data.sh

set -eo pipefail
trap 'echo "Hit an unexpected and unchecked error. Exiting."' ERR

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

ACTIVE_CONFIG="${SCRIPT_DIR}/config/active_config.sh"

if [[ -L ${ACTIVE_CONFIG} ]]; then
  # shellcheck source=/dev/null
  source "$(readlink "${ACTIVE_CONFIG}")"
else
  log.error "No active config exists in ${ACTIVE_CONFIG}. Exiting..."
  exit 1
fi

LOCAL_RESULTS_DIR="${SCRIPT_DIR}/results"
LOCAL_RESULTS_DATA_DIR="${LOCAL_RESULTS_DIR}/io500_results"

# BEGIN: Logging variables and functions
LOG_LEVEL=INFO

declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1  [WARN]=2   [ERROR]=3 [FATAL]=4 [OFF]=5)
declare -A LOG_COLORS=([DEBUG]=2 [INFO]=12 [WARN]=3 [ERROR]=1 [FATAL]=9 [OFF]=0 [OTHER]=15)
LOG_LINE_CHAR="-"
if [[ -t 1 ]]; then
  LOG_COLS=$(tput cols)
else
  LOG_COLS=40
fi

log() {
  local msg="$1"
  local lvl=${2:-INFO}
  if [[ ${LOG_LEVELS[$LOG_LEVEL]} -le ${LOG_LEVELS[$lvl]} ]]; then
    if [[ -t 1 ]]; then tput setaf "${LOG_COLORS[$lvl]}"; fi
    printf "[%-5s] %s\n" "$lvl" "${msg}" 1>&2
    if [[ -t 1 ]]; then tput sgr0; fi
  fi
}

log.debug() { log "${1}" "DEBUG" ; }
log.info()  { log "${1}" "INFO"  ; }
log.warn()  { log "${1}" "WARN"  ; }
log.error() { log "${1}" "ERROR" ; }
log.fatal() { log "${1}" "FATAL" ; }

log.line() {
  local line_char="${1:-$LOG_LINE_CHAR}"
  local line_width="${2:-$LOG_COLS}"
  local fg_color="${3:-${LOG_COLORS[OTHER]}}"
  local line
  line=$(printf "%${line_width}s" | tr " " "${line_char}")
  if [[ ${LOG_LEVELS[$LOG_LEVEL]} -le ${LOG_LEVELS[OFF]} ]]; then
    if [[ -t 1 ]];then tput setaf "${fg_color}"; fi
    printf -- "%s\n" "${line}" 1>&2
    if [[ -t 1 ]]; then tput sgr0; fi
  fi
}

# log.section msg [line_width] [line_char] [fg_color]
log.section() {
  local msg="${1:-}"
  local line_width="${2:-$LOG_COLS}"
  local line_char="${3:-$LOG_LINE_CHAR}"
  local fg_color="${4:-${LOG_COLORS[OTHER]}}"
  if [[ ${LOG_LEVELS[$LOG_LEVEL]} -le ${LOG_LEVELS[OFF]} ]]; then
    log.line "${line_char}" "${line_width}" "${fg_color}"
    if [[ -t 1 ]];then tput setaf "${fg_color}"; fi
    printf "%s\n" "${msg}" 1>&2
    log.line "${line_char}" "${line_width}" "${fg_color}"
    if [[ -t 1 ]]; then tput sgr0; fi
  fi
}
# END: Logging variables and functions

get_results_tar_files() {
  mkdir -p "${LOCAL_RESULTS_DATA_DIR}"
  FIRST_CLIENT_IP=$(grep ssh "${SCRIPT_DIR}/login" | awk '{print $4}')
  log.debug "FIRST_CLIENT_IP=${FIRST_CLIENT_IP}"
  ssh -F ./tmp/ssh_config "${FIRST_CLIENT_IP}" "ls -1 ${IO500_TEST_CONFIG}*.tar.gz" > /tmp/results_tar_files

  # shellcheck disable=SC2013
  for f in $(cat /tmp/results_tar_files); do
    LOCAL_RESULTS_TAR_FILE="${LOCAL_RESULTS_DATA_DIR}/${f}"
    if [[ ! -f "${LOCAL_RESULTS_TAR_FILE}" ]]; then
      scp -F tmp/ssh_config  "${FIRST_CLIENT_IP}":"~/${f}" "${LOCAL_RESULTS_DATA_DIR}/"
      echo "Downloaded results file: ${LOCAL_RESULTS_TAR_FILE}"
    else
      echo "File already exists: ${LOCAL_RESULTS_TAR_FILE}"
    fi
    process_results_file "${LOCAL_RESULTS_DATA_DIR}/${f}"
  done
}

process_results_file() {
  local results_file=$1
  local timestamp
  timestamp=$(tar --to-stdout -xzf "${results_file}" io500_run_timestamp.txt)
  local tmp_dir="${LOCAL_RESULTS_DATA_DIR}/tmp/${timestamp}"

  log.info "PROCESSING RESULTS FILE: $(basename "${results_file}")" 1

  mkdir -p "${tmp_dir}"
  log.info "Extracting ${results_file} to ${tmp_dir}"
  tar -xzf "${results_file}" -C "${tmp_dir}"
  local result_summary_file
  result_summary_file=$(find "${tmp_dir}" -type f -name result_summary.txt)
  print_results "${result_summary_file}" "${timestamp}"

  if [[ -d "${LOCAL_RESULTS_DATA_DIR}/tmp" ]]; then
    rm -rf "${LOCAL_RESULTS_DATA_DIR}/tmp"
  fi
}

print_result_value() {
  local summary_file="$1"
  local metric="$2"
  local timestamp="$3"
  local metric_line
  metric_line=$(grep "${metric}" "${summary_file}")
  local metric_value
  metric_value=$(echo "${metric_line}" | awk '{print $3}')
  local metric_measurment
  metric_measurment=$(echo "${metric_line}" | awk '{print $4}')
  local metric_time_secs
  metric_time_secs=$(echo "${metric_line}" | awk '{print $7}')
  printf "%s %s %s %s %s %s\n" "${IO500_TEST_CONFIG_ID}" "${timestamp}" "${metric}" "${metric_value}" "${metric_measurment}" "${metric_time_secs}"
}

print_results() {
  local result_summary_file=$1
  local timestamp=$2

  print_result_value "${result_summary_file}" "ior-easy-write" "${timestamp}"
  print_result_value "${result_summary_file}" "mdtest-easy-write" "${timestamp}"
  print_result_value "${result_summary_file}" "ior-hard-write" "${timestamp}"
  print_result_value "${result_summary_file}" "mdtest-hard-write" "${timestamp}"
  print_result_value "${result_summary_file}" "find" "${timestamp}"
  print_result_value "${result_summary_file}" "ior-easy-read" "${timestamp}"
  print_result_value "${result_summary_file}" "mdtest-easy-stat" "${timestamp}"
  print_result_value "${result_summary_file}" "ior-hard-read" "${timestamp}"
  print_result_value "${result_summary_file}" "mdtest-hard-stat" "${timestamp}"
  print_result_value "${result_summary_file}" "mdtest-easy-delete" "${timestamp}"
  print_result_value "${result_summary_file}" "mdtest-hard-read" "${timestamp}"
  print_result_value "${result_summary_file}" "mdtest-hard-delete" "${timestamp}"

  #print bandwidth line
  local bandwidth_line
  bandwidth_line="$(grep 'SCORE' "${result_summary_file}" | cut -d ':' -f 1 | sed 's/\[SCORE \] //g')"
  printf "%s %s %s\n" "${IO500_TEST_CONFIG_ID}" "${timestamp}" "${bandwidth_line}"

  local iops_line
  iops_line="$(grep 'SCORE' "${result_summary_file}" | sed 's/\[SCORE \] //g' | cut -d ':' -f 2 | awk '{$1=$1;print}')"
  printf "%s %s %s\n" "${IO500_TEST_CONFIG_ID}" "${timestamp}" "${iops_line}"

  local total_line
  total_line="$(grep 'SCORE' "${result_summary_file}" | sed 's/\[SCORE \] //g' | cut -d ':' -f 3 | awk '{$1=$1;print}' | sed 's/ \[INVALID\]//g')"
  printf "%s %s %s\n" "${IO500_TEST_CONFIG_ID}" "${timestamp}" "${total_line}"
}

main() {
  get_results_tar_files
}

main


# C-16C4S-NOGVNIC-1	ior-easy-write	14.121246	GiB/s	65.187
# C-16C4S-NOGVNIC-1	mdtest-easy-write	533.025035	kIOPS	63.665
# C-16C4S-NOGVNIC-1	ior-hard-write	9.391863	GiB/s	60.94
# C-16C4S-NOGVNIC-1	mdtest-hard-write	214.297617	kIOPS	64.344
# C-16C4S-NOGVNIC-1	find	68.192322	kIOPS	688.903
# C-16C4S-NOGVNIC-1	ior-easy-read	14.441245	GiB/s	62.736
# C-16C4S-NOGVNIC-1	mdtest-easy-stat	447.921375	kIOPS	75.605
# C-16C4S-NOGVNIC-1	ior-hard-read	9.584314	GiB/s	59.722
# C-16C4S-NOGVNIC-1	mdtest-hard-stat	429.085094	kIOPS	32.655
# C-16C4S-NOGVNIC-1	mdtest-easy-delete	251.525253	kIOPS	134.135
# C-16C4S-NOGVNIC-1	mdtest-hard-read	315.482662	kIOPS	44.039
# C-16C4S-NOGVNIC-1	mdtest-hard-delete	226.93919	kIOPS	65.753
# C-16C4S-NOGVNIC-1	Bandwidth	11.639856	GiB/s
# C-16C4S-NOGVNIC-1	IOPS	268.434931	kiops
# C-16C4S-NOGVNIC-1	TOTAL	55.897621
