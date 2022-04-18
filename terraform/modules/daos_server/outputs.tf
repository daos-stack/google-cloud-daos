
output "access_points" {
  description = "List of DAOS servers to use as access points"
  value       = local.access_points
  depends_on = [
    local.access_points
  ]
}

output "daos_agent_yml" {
  description = "YAML to configure the daos agent. This is typically saved in /etc/daos/daos_agent.yml"
  value       = local.daos_agent_yaml_content
}

output "daos_control_yml" {
  description = "YAML configuring DAOS control. This is typically saved in /etc/daos/daos_control.yml"
  value       = local.daos_control_yaml_content
}

output "daos_client_install_script" {
  description = "Script to install the DAOS client package."
  value       = local.daos_client_install_script_content
}
