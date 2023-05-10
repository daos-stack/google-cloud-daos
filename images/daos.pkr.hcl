// Copyright 2023 Intel Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

packer {
  required_plugins {
    googlecompute = {
      version = ">= v1.0.11"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "daos_version" {
  type = string
}

variable "daos_repo_base_url" {
  type = string
}

variable "daos_packages_repo_file" {
  type = string
}

variable "daos_install_type" {
  type = string
}

variable "image_family" {
  type = string
}

variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "use_iap" {
  type = bool
}

variable "enable_oslogin" {
  type    = string
  default = "false"
}

variable "machine_type" {
  type    = string
  default = "n2-standard-32"
}

variable "source_image_family" {
  type    = string
  default = "hpc-rocky-linux-8"
}

variable "source_image_project_id" {
  type    = string
  default = "cloud-hpc-image-public"
}

variable "image_guest_os_features" {
  type    = list(string)
  default = ["GVNIC"]
}

variable "disk_size" {
  type    = string
  default = "20"
}

variable "state_timeout" {
  type    = string
  default = "10m"
}

variable "scopes" {
  type    = list(string)
  default = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "use_internal_ip" {
  type    = bool
  default = true
}

variable "omit_external_ip" {
  type    = bool
  default = false
}

locals {
  version_timestamp = "v${formatdate("YYYYMMDD-hhmmss", timestamp())}"
}

source "googlecompute" "daos" {
  source_image_family     = var.source_image_family
  source_image_project_id = ["${var.source_image_project_id}"]
  image_family            = var.image_family
  image_name              = "${var.image_family}-${local.version_timestamp}"
  image_guest_os_features = var.image_guest_os_features
  machine_type            = var.machine_type
  disk_size               = var.disk_size
  project_id              = var.project_id
  zone                    = var.zone
  scopes                  = var.scopes
  use_iap                 = var.use_iap
  use_internal_ip         = var.use_internal_ip
  omit_external_ip        = var.omit_external_ip
  ssh_username            = "packer"
  state_timeout           = var.state_timeout
  metadata = {
    enable-oslogin = var.enable_oslogin
  }
}

build {
  sources = ["source.googlecompute.daos"]

  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
    inline = [
      "dnf -y install epel-release",
      "dnf -y install ansible"
    ]
  }

  provisioner "ansible-local" {
    playbook_file = "./ansible_playbooks/tune.yml"
  }

  provisioner "ansible-local" {
    playbook_file = "./ansible_playbooks/daos.yml"
    extra_arguments = [
      "--extra-vars",
      "\"daos_version=${var.daos_version} daos_repo_base_url=${var.daos_repo_base_url} daos_packages_repo_file=${var.daos_packages_repo_file} daos_install_type=${var.daos_install_type}\""
    ]
  }
}
