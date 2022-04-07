provider "google" {
  region = var.region
}

module "daos_client" {
  source              = "../../modules/daos_client"
  project_id          = var.project_id
  region              = var.region
  zone                = var.zone
  network_name        = var.network_name
  subnetwork_project  = var.subnetwork_project
  subnetwork_name     = var.subnetwork_name
  number_of_instances = var.client_number_of_instances
  labels              = var.client_labels
  preemptible         = var.client_preemptible
  mig_name            = var.client_mig_name
  template_name       = var.client_template_name
  instance_base_name  = var.client_instance_base_name
  machine_type        = var.client_machine_type
  os_family           = var.client_os_family
  os_project          = var.client_os_project
  os_disk_type        = var.client_os_disk_type
  os_disk_size_gb     = var.client_os_disk_size_gb
  service_account     = var.client_service_account
  daos_agent_yml      = var.client_daos_agent_yml
  daos_control_yml    = var.client_daos_control_yml
}
