# DAOS Client MIG

Creates a managed instance group running ```number_of_instances``` DAOS clients.

A DAOS client is simply an instance based on an image containing all DAOS packages and dependencies (can be created with the image scripts).

## Requirements

Please make sure you go through the [Requirements section](../../modules/daos_client/README.md) of the DAOS client module.

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 3.54 |

## Setup

1. Create ```terraform.tfvars``` in this directory or the directory where you're running this example.
2. Copy the ```terraform.tfvars.example``` content into ```terraform.tfvars``` file and update the contents to match your environment.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_daos_client"></a> [daos\_client](#module\_daos\_client) | ../../modules/daos_client | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_instance_base_name"></a> [instance\_base\_name](#input\_instance\_base\_name) | MIG instance base names to use | `string` | `"daos-client"` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | GCP machine type. ie. e2-medium | `string` | `"n2-highmem-16"` | no |
| <a name="input_mig_name"></a> [mig\_name](#input\_mig\_name) | MIG name | `string` | `"daos-client"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Set of key/value label pairs to assign to daos-client instances | `any` | n/a | no |
| <a name="input_network"></a> [network](#input\_network) | GCP network to use | `string` | n/a | yes |
| <a name="input_number_of_instances"></a> [number\_of\_instances](#input\_number\_of\_instances) | Number of daos clients to bring up | `number` | `2` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS disk size in GB | `number` | `20` | no |
| <a name="input_os_disk_type"></a> [os\_disk\_type](#input\_os\_disk\_type) | OS disk type ie. pd-ssd, pd-standard | `string` | `"pd-ssd"` | no |
| <a name="input_os_family"></a> [os\_family](#input\_os\_family) | OS GCP image family | `any` | `null` | no |
| <a name="input_os_project"></a> [os\_project](#input\_os\_project) | OS GCP image project name | `any` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project to use | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region to create and test resources in | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | GCP sub-network to use | `string` | n/a | yes |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The GCP project where the subnetwork is defined | `string` | n/a | yes |
| <a name="input_template_name"></a> [template\_name](#input\_template\_name) | MIG template name | `string` | `"daos-client"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | The GCP zone to create and test resources in | `string` | n/a | yes |

## Outputs

No outputs.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Copyright 2021 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

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
| <a name="module_daos_client"></a> [daos\_client](#module\_daos\_client) | ../../modules/daos_client | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_instance_base_name"></a> [instance\_base\_name](#input\_instance\_base\_name) | MIG instance base names to use | `string` | `"daos-client"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Set of key/value label pairs to assign to daos-client instances | `any` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | GCP machine type. ie. e2-medium | `string` | `"n2-highmem-16"` | no |
| <a name="input_mig_name"></a> [mig\_name](#input\_mig\_name) | MIG name | `string` | `"daos-client"` | no |
| <a name="input_network"></a> [network](#input\_network) | GCP network to use | `string` | n/a | yes |
| <a name="input_number_of_instances"></a> [number\_of\_instances](#input\_number\_of\_instances) | Number of daos clients to bring up | `number` | `2` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS disk size in GB | `number` | `20` | no |
| <a name="input_os_disk_type"></a> [os\_disk\_type](#input\_os\_disk\_type) | OS disk type ie. pd-ssd, pd-standard | `string` | `"pd-ssd"` | no |
| <a name="input_os_family"></a> [os\_family](#input\_os\_family) | OS GCP image family | `string` | `null` | no |
| <a name="input_os_project"></a> [os\_project](#input\_os\_project) | OS GCP image project name | `string` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project to use | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region to create and test resources in | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | GCP sub-network to use | `string` | n/a | yes |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The GCP project where the subnetwork is defined | `string` | n/a | yes |
| <a name="input_template_name"></a> [template\_name](#input\_template\_name) | MIG template name | `string` | `"daos-client"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | The GCP zone to create and test resources in | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->