/**
 * Copyright 2021 Google LLC
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
  servers            = format("%s-[%04s-%04s]", var.instance_base_name, 1, var.number_of_instances)
  max_aps            = var.number_of_instances > 5 ? 5 : (var.number_of_instances % 2) == 1 ? var.number_of_instances : var.number_of_instances - 1
  access_points      = formatlist("%s-%04s", var.instance_base_name, range(1, local.max_aps + 1))
  scm_size           = var.daos_scm_size
  # To get nr_hugepages value: (targets * 1Gib) / hugepagesize
  huge_pages  = (var.daos_disk_count * 1048576) / 2048
  targets     = var.daos_disk_count
  crt_timeout = var.daos_crt_timeout
  daos_server_yaml_content = templatefile(
    "${path.module}/templates/daos_server.yml.tftpl",
    {
      access_points = local.access_points
      nr_hugepages  = local.huge_pages
      targets       = local.targets
      scm_size      = local.scm_size
      crt_timeout   = local.crt_timeout
    }
  )
  daos_control_yaml_content = templatefile(
    "${path.module}/templates/daos_control.yml.tftpl",
    {
      servers = [local.servers]
    }
  )
  daos_agent_yaml_content = templatefile(
    "${path.module}/templates/daos_agent.yml.tftpl",
    {
      access_points = local.access_points
    }
  )
  server_startup_script = file(
  "${path.module}/templates/daos_startup_script.tftpl")

  configure_daos_content = templatefile(
    "${path.module}/templates/configure_daos.tftpl",
    {
      servers = local.servers
      pools   = var.pools
    }
  )
}

data "google_compute_image" "os_image" {
  family  = var.os_family
  project = local.os_project
}

resource "google_compute_instance_template" "daos_sig_template" {
  name           = var.template_name
  machine_type   = var.machine_type
  can_ip_forward = false
  tags           = ["daos-server"]
  project        = var.project_id
  region         = var.region
  labels         = var.labels

  disk {
    source_image = data.google_compute_image.os_image.self_link
    auto_delete  = true
    boot         = true
    disk_type    = var.os_disk_type
    disk_size_gb = var.os_disk_size_gb
  }

  dynamic "disk" {
    for_each = toset(range(var.daos_disk_count))
    content {
      auto_delete  = true
      interface    = "NVME"
      disk_type    = var.daos_disk_type
      disk_size_gb = 375
      type         = "SCRATCH"
    }
  }

  network_interface {
    network            = var.network_name
    subnetwork         = var.subnetwork_name
    subnetwork_project = local.subnetwork_project
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

resource "google_compute_instance_group_manager" "daos_sig" {
  description = "Stateful Instance group for DAOS servers"
  name        = var.mig_name

  version {
    instance_template = google_compute_instance_template.daos_sig_template.self_link
  }

  base_instance_name = var.instance_base_name
  zone               = var.zone
  project            = var.project_id
}


resource "google_compute_per_instance_config" "named_instances" {
  zone                   = var.zone
  project                = var.project_id
  instance_group_manager = google_compute_instance_group_manager.daos_sig.name
  count                  = var.number_of_instances
  name                   = format("%s-%04d", var.instance_base_name, sum([count.index, 1]))
  preserved_state {
    metadata = {
      inst_type                 = "daos-server"
      enable-oslogin            = "true"
      inst_nr                   = var.number_of_instances
      inst_base_name            = var.instance_base_name
      daos_server_yaml_content  = local.daos_server_yaml_content
      daos_control_yaml_content = local.daos_control_yaml_content
      daos_agent_yaml_content   = local.daos_agent_yaml_content
      startup-script            = local.server_startup_script
      # Adding a reference to the instance template used causes the stateful instance to update
      # if the instance template changes. Otherwise there is no explicit dependency and template
      # changes may not occur on the stateful instance
      instance_template = google_compute_instance_template.daos_sig_template.self_link
    }
  }
}
