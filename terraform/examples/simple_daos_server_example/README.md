# DAOS Server Simple Example

Creates a managed instance group running ```number_of_instances``` DAOS servers.

## Setup

1. Create ```terraform.tfvars``` in this directory or the directory where you're running this example.
2. Copy the ```terraform.tfvars.example``` content into ```terraform.tfvars``` file and update the contents to match your environment.


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.14.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.54.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_daos_server"></a> [daos\_server](#module\_daos\_server) | ../../modules/daos_server | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_daos_crt_timeout"></a> [daos\_crt\_timeout](#input\_daos\_crt\_timeout) | crt\_timeout | `number` | `300` | no |
| <a name="input_daos_disk_count"></a> [daos\_disk\_count](#input\_daos\_disk\_count) | Number of local ssd's to use | `number` | `16` | no |
| <a name="input_daos_disk_type"></a> [daos\_disk\_type](#input\_daos\_disk\_type) | Daos disk type to use. For now only suported one is local-ssd | `string` | `"local-ssd"` | no |
| <a name="input_daos_scm_size"></a> [daos\_scm\_size](#input\_daos\_scm\_size) | scm\_size | `number` | `200` | no |
| <a name="input_instance_base_name"></a> [instance\_base\_name](#input\_instance\_base\_name) | MIG instance base names to use | `string` | `"daos-server"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Set of key/value label pairs to assign to daos-server instances | `any` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | GCP machine type. | `string` | `"n2-custom-36-215040"` | no |
| <a name="input_mig_name"></a> [mig\_name](#input\_mig\_name) | MIG name | `string` | `"daos-server"` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the GCP network to use | `string` | `"default"` | no |
| <a name="input_number_of_instances"></a> [number\_of\_instances](#input\_number\_of\_instances) | Number of daos servers to bring up | `number` | `4` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS disk size in GB | `number` | `20` | no |
| <a name="input_os_disk_type"></a> [os\_disk\_type](#input\_os\_disk\_type) | OS disk type ie. pd-ssd, pd-standard | `string` | `"pd-ssd"` | no |
| <a name="input_os_family"></a> [os\_family](#input\_os\_family) | OS GCP image family | `string` | `"daos-server-centos-7"` | no |
| <a name="input_os_project"></a> [os\_project](#input\_os\_project) | OS GCP image project name. Defaults to project\_id if null. | `string` | `null` | no |
| <a name="input_preemptible"></a> [preemptible](#input\_preemptible) | If preemptible instances | `string` | `false` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project to use | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region to create and test resources in | `string` | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string,<br>    scopes = set(string)<br>  })</pre> | <pre>{<br>  "email": null,<br>  "scopes": [<br>    "https://www.googleapis.com/auth/devstorage.read_only",<br>    "https://www.googleapis.com/auth/logging.write",<br>    "https://www.googleapis.com/auth/monitoring.write",<br>    "https://www.googleapis.com/auth/servicecontrol",<br>    "https://www.googleapis.com/auth/service.management.readonly",<br>    "https://www.googleapis.com/auth/trace.append"<br>  ]<br>}</pre> | no |
| <a name="input_subnetwork_name"></a> [subnetwork\_name](#input\_subnetwork\_name) | Name of the GCP sub-network to use | `string` | `"default"` | no |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The GCP project where the subnetwork is defined. Defaults to project\_id if null. | `string` | `null` | no |
| <a name="input_template_name"></a> [template\_name](#input\_template\_name) | MIG template name | `string` | `"daos-server"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | The GCP zone to create and test resources in | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->