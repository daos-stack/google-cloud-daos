/**
 * Copyright 2023 Google LLC
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

locals {
  os_project         = var.os_project != null ? var.os_project : var.project_id
  subnetwork_project = var.subnetwork_project != null ? var.subnetwork_project : var.project_id
  # Google Virtual NIC (gVNIC) network interface
  nic_type                    = var.gvnic ? "GVNIC" : "VIRTIO_NET"
  total_egress_bandwidth_tier = var.gvnic ? "TIER_1" : "DEFAULT"
  certs_install_content       = var.certs_install_content

  startup_script = templatefile(
    "${path.module}/templates/daos_startup_script.tftpl",
    {
      certs_install_content = local.certs_install_content
    }
  )
}

data "google_compute_image" "os_image" {
  family  = var.os_family
  project = local.os_project
}

resource "google_compute_disk" "boot_disk" {
  project = var.project_id
  count   = var.number_of_instances
  name    = format("%s-%04d-boot-disk", var.instance_base_name, count.index + 1)
  image   = data.google_compute_image.os_image.self_link
  type    = var.os_disk_type
  size    = var.os_disk_size_gb
  zone    = var.zone
}

resource "google_compute_instance" "named_instances" {
  provider       = google-beta
  zone           = var.zone
  project        = var.project_id
  labels         = var.labels
  count          = var.number_of_instances
  name           = format("%s-%04d", var.instance_base_name, count.index + 1)
  can_ip_forward = false
  tags           = ["daos-client"]
  machine_type   = var.machine_type

  metadata = {
    inst_type                 = "daos-client"
    enable-oslogin            = "true"
    daos_control_yaml_content = var.daos_control_yml
    daos_agent_yaml_content   = var.daos_agent_yml
    startup-script            = local.startup_script
  }


  boot_disk {
    source      = google_compute_disk.boot_disk[count.index].self_link
    auto_delete = true
  }

  network_interface {
    network            = var.network_name
    subnetwork         = var.subnetwork_name
    subnetwork_project = local.subnetwork_project
    nic_type           = local.nic_type
  }

  network_performance_config {
    total_egress_bandwidth_tier = local.total_egress_bandwidth_tier
  }

  dynamic "service_account" {
    for_each = var.service_account == null ? [] : [var.service_account]
    content {
      email  = lookup(service_account.value, "email", null)
      scopes = lookup(service_account.value, "scopes", null)
    }
  }

  scheduling {
    preemptible       = var.preemptible
    automatic_restart = false
  }
}
