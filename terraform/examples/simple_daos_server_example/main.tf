provider "google" {
  region = var.region
}

module "daos_server" {
  source             = "../../modules/daos_server"
  project_id         = var.project_id
  network_name       = var.network_name
  subnetwork_name    = var.subnetwork_name
  subnetwork_project = var.subnetwork_project
  region             = var.region
  zone               = var.zone
  labels             = var.labels

  number_of_instances = var.number_of_instances
  daos_disk_count     = var.daos_disk_count
  daos_disk_type      = var.daos_disk_type
  daos_crt_timeout    = var.daos_crt_timeout
  daos_scm_size       = var.daos_scm_size

  instance_base_name = var.instance_base_name
  os_disk_size_gb    = var.os_disk_size_gb
  os_disk_type       = var.os_disk_type
  template_name      = var.template_name
  mig_name           = var.mig_name
  machine_type       = var.machine_type
  os_project         = var.os_project
  os_family          = var.os_family

  service_account = var.service_account
  preemptible     = var.preemptible
  pools           = var.pools
}
