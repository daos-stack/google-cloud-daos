/**
 * Copyright 2023 Intel Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project_id" {
  description = "The GCP project"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "zone" {
  description = "The GCP zone"
  type        = string
}

variable "network_name" {
  description = "Name of the GCP network"
  default     = "default"
  type        = string
}

variable "subnetwork_name" {
  description = "Name of the GCP sub-network"
  default     = "default"
  type        = string
}

variable "subnetwork_project" {
  description = "The GCP project where the subnetwork is defined"
  type        = string
  default     = null
}

variable "allow_insecure" {
  description = "Sets the allow_insecure setting in the transport_config section of the daos_*.yml files"
  default     = false
  type        = bool
}

variable "server_labels" {
  description = "Set of key/value label pairs to assign to daos-server instances"
  type        = any
  default     = {}
}

variable "server_os_family" {
  description = "OS GCP image family"
  type        = string
  default     = "daos-server-hpc-rocky-8"
}

variable "server_os_project" {
  description = "OS GCP image project name. Defaults to project_id if null."
  default     = null
  type        = string
}

variable "server_os_disk_size_gb" {
  description = "OS disk size in GB"
  default     = 20
  type        = number
}

variable "server_os_disk_type" {
  description = "OS disk type ie. pd-ssd, pd-standard"
  default     = "pd-ssd"
  type        = string
}

variable "server_machine_type" {
  description = "GCP machine type. ie. e2-medium"
  default     = "n2-custom-36-215040"
  type        = string
}

variable "server_instance_base_name" {
  description = "Base name for DAOS server instances"
  default     = "daos-server"
  type        = string
}

variable "server_number_of_instances" {
  description = "Number of daos servers to bring up"
  default     = 4
  type        = number
}

variable "server_daos_disk_count" {
  description = "Number of local ssd's to use"
  default     = 16
  type        = number
}

variable "server_service_account" {
  description = "Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account."
  type = object({
    email  = string,
    scopes = set(string)
  })
  default = {
    email = null
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

variable "server_preemptible" {
  description = "If preemptible instances"
  default     = false
  type        = string
}

variable "server_daos_scm_size" {
  description = "scm_size"
  default     = 200
  type        = number
}

variable "server_daos_crt_timeout" {
  description = "crt_timeout"
  default     = 300
  type        = number
}

variable "server_gvnic" {
  description = "Use Google Virtual NIC (gVNIC) network interface"
  default     = false
  type        = bool
}

variable "server_pools" {
  description = "List of pools and containers to be created"
  default     = []
  type = list(object({
    name       = string
    size       = string
    tier_ratio = number
    user       = string
    group      = string
    acls       = list(string)
    properties = map(any)
    containers = list(object({
      name            = string
      type            = string
      user            = string
      group           = string
      acls            = list(string)
      properties      = map(any)
      user_attributes = map(any)
    }))
  }))
}

variable "client_labels" {
  description = "Set of key/value label pairs to assign to daos-client instances"
  type        = any
  default     = {}
}

variable "client_os_family" {
  description = "OS GCP image family"
  default     = "daos-client-hpc-rocky-8"
  type        = string
}

variable "client_os_project" {
  description = "OS GCP image project name. Defaults to project_id if null."
  default     = null
  type        = string
}

variable "client_os_disk_size_gb" {
  description = "OS disk size in GB"
  default     = 20
  type        = number
}

variable "client_os_disk_type" {
  description = "OS disk type ie. pd-ssd, pd-standard"
  default     = "pd-ssd"
  type        = string
}

variable "client_machine_type" {
  description = "GCP machine type. ie. c2-standard-16"
  default     = "c2-standard-16"
  type        = string
}

variable "client_instance_base_name" {
  description = "Base name for DAOS client instances"
  default     = "daos-client"
  type        = string
}

variable "client_number_of_instances" {
  description = "Number of daos clients to bring up"
  default     = 16
  type        = number
}

variable "client_service_account" {
  description = "Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account."
  type = object({
    email  = string,
    scopes = set(string)
  })
  default = {
    email = null
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

variable "client_preemptible" {
  description = "If preemptible instances"
  default     = false
  type        = string
}

variable "client_gvnic" {
  description = "Use Google Virtual NIC (gVNIC) network interface on DAOS clients"
  default     = false
  type        = bool
}
