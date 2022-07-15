# DAOS Cluster Example

This example Terraform configuration demonstrates how to use the [DAOS Terraform Modules](../../modules) to deploy a DAOS cluster consisting of servers and clients.

## Pre-deployment

If you have not completed the [pre-deployment steps](../../../README.md#pre-deployment-steps) please complete those steps before continuing to run this Terraform example.

## Quickstart in Cloudshell

Click the button below to run this example in a Cloudshell tutorial.  The tutorial will walk through each of the steps described in this README.md file.

[![DAOS on GCP Setup](http://gstatic.com/cloudssh/images/open-btn.png)](https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/daos-stack/google-cloud-daos&cloudshell_git_branch=main&shellonly=true&tutorial=docs/tutorials/example_daos_cluster.md)

## Terraform Files

List of Terraform files in this example

| Filename                      | Description                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------- |
| main.tf                       | Main Terrform configuration file containing resource definitions                |
| variables.tf                  | Variable definitions for variables used in main.tf                              |
| versions.tf                   | Provider definitions                                                            |
| terraform.tfvars.perf.example | Pre-Configured set of set of variables focused on performance                   |
| terraform.tfvars.tco.example  | Pre-Configured set of set of variables focused on lower total cost of ownership |

## Deploy a DAOS Cluster With This Example

The following sections describe how to deploy a DAOS cluster with this example Terraform configuration.

### Create a `terraform.tfvars` file

Before you run any `terraform` commands you need to create a `terraform.tfvars` file in the `terraform/examples/daos_cluster` directory.

The `terraform.tfvars` file will contain the variable values for the configuration.

To ensure a successful deployment of a DAOS cluster there are two `terraform.tfvars.*.example` files that you can choose from.

You will need to decide which of these files to copy to `terraform.tfvars`.

#### The terraform.tfvars.tco.example file

The `terraform.tfvars.tco.example` contains variables for a DAOS cluster deployment with
- 16 DAOS Client instances
- 4 DAOS Server instances
  Each server instance has sixteen 375GB NVMe SSDs

To use the `terraform.tfvars.tco.example` file

```bash
cp terraform.tfvars.tco.example terraform.tfvars
```

#### The terraform.tfvars.perf.example file

The `terraform.tfvars.perf.example` contains variables for a DAOS cluster deployment with
- 16 DAOS Client instances
- 4 DAOS Server instances
  Each server instances has four 375GB NVMe SSDs

To use the ```terraform.tfvars.perf.example``` file run

```bash
cp terraform.tfvars.perf.example terraform.tfvars
```

### Update `terraform.tfvars` with your project id

Now that you have a `terraform.tfvars` file you need to replace the `<project_id>` placeholder in the file with your GCP project id.

To update the project id in `terraform.tfvars` run

```bash
PROJECT_ID=$(gcloud config list --format 'value(core.project)')
sed -i "s/<project_id>/${PROJECT_ID}/g" terraform.tfvars
```

### Deploy the DAOS cluster

> **Billing Notification!**
>
> Running this example will incur charges in your project.
>
> To avoid surprises, be sure to monitor your costs associated with running this example.
>
> Don't forget to shut down the DAOS cluster with `terraform destroy` when you are finished.

To deploy the DAOS cluster

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Perform DAOS administration tasks

After your DAOS cluster has been deployed you can log into the first DAOS client instance to perform administrative tasks.

#### Log into the first DAOS client instance

Verify that the daos-client and daos-server instances are running

```bash
gcloud compute instances list \
  --filter="name ~ daos" \
  --format="value(name,INTERNAL_IP)"
```

Log into the first client instance

```bash
gcloud compute ssh daos-client-0001
```

#### Verify that all daos-server instances have joined

```bash
sudo dmg system query -v
```

The *State* column should display "Joined" for all servers.

```
Rank UUID                                 Control Address   Fault Domain      State  Reason
---- ----                                 ---------------   ------------      -----  ------
0    0796c576-5651-4e37-aa15-09f333d2d2b8 10.128.0.35:10001 /daos-server-0001 Joined
1    f29f7058-8abb-429f-9fd3-8b13272d7de0 10.128.0.77:10001 /daos-server-0003 Joined
2    09fc0dab-c238-4090-b3f8-da2bd4dce108 10.128.0.81:10001 /daos-server-0002 Joined
3    2cc9140b-fb12-4777-892e-7d190f6dfb0f 10.128.0.30:10001 /daos-server-0004 Joined
```

#### Create a Pool

Check free NVMe storage.

```bash
sudo dmg storage query usage
```

From the output you can see there are 4 servers each with 1.6TB free. That means there is a total of 6.4TB free.

```
Hosts            SCM-Total SCM-Free SCM-Used NVMe-Total NVMe-Free NVMe-Used
-----            --------- -------- -------- ---------- --------- ---------
daos-server-0001 48 GB     48 GB    0 %      1.6 TB     1.6 TB    0 %
daos-server-0002 48 GB     48 GB    0 %      1.6 TB     1.6 TB    0 %
daos-server-0003 48 GB     48 GB    0 %      1.6 TB     1.6 TB    0 %
daos-server-0004 48 GB     48 GB    0 %      1.6 TB     1.6 TB    0 %
```

Create one pool that uses the entire 6.4TB.

```bash
sudo dmg pool create -z 6.4TB -t 3 --label=pool1
```

For more information about pools see

- https://docs.daos.io/latest/overview/storage/#daos-pool
- https://docs.daos.io/latest/admin/pool_operations/


## Create a Container

Create a container in the pool

```bash
daos container create --type=POSIX --properties=rf:0 --label=cont1 pool1
```

For more information about containers see https://docs.daos.io/latest/overview/storage/#daos-container

### Mount the container

Mount the container with `dfuse`

```bash
MOUNT_DIR="${HOME}/daos/cont1"
mkdir -p "${MOUNT_DIR}"
dfuse --singlethread --pool=pool1 --container=cont1 --mountpoint="${MOUNT_DIR}"
df -h -t fuse.daos
```

You can now store files in the DAOS container mounted on `${HOME}/daos/cont1`.

For more information about DFuse see the [DAOS FUSE section of the User Guide](https://docs.daos.io/v2.0/user/filesystem/?h=dfuse#dfuse-daos-fuse).

### Use the Storage

The `cont1` container is now mounted on `${HOME}/daos/cont1`

Create a 20GiB file which will be stored in the DAOS filesystem.

```bash
cd ${HOME}/daos/cont1
time LD_PRELOAD=/usr/lib64/libioil.so \
  dd if=/dev/zero of=./test21G.img bs=1G count=20
```

### Unmount the container

```bash
fusermount -u ${HOME}/daos/cont1
```

### Remove DAOS cluster deployment

To destroy the DAOS cluster run

```bash
terraform destroy
```

This will shut down all DAOS server and client instances.

# Terraform Documentation

Documentation for the `terraform/examples/daos_cluster` Terraform configuration.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Copyright 2022 Intel Corporation

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
| <a name="module_daos_server"></a> [daos\_server](#module\_daos\_server) | ../../modules/daos_server | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_insecure"></a> [allow\_insecure](#input\_allow\_insecure) | Sets the allow\_insecure setting in the transport\_config section of the daos\_*.yml files | `bool` | `false` | no |
| <a name="input_client_gvnic"></a> [client\_gvnic](#input\_client\_gvnic) | Use Google Virtual NIC (gVNIC) network interface on DAOS clients | `bool` | `false` | no |
| <a name="input_client_instance_base_name"></a> [client\_instance\_base\_name](#input\_client\_instance\_base\_name) | MIG instance base names to use | `string` | `"daos-client"` | no |
| <a name="input_client_labels"></a> [client\_labels](#input\_client\_labels) | Set of key/value label pairs to assign to daos-client instances | `any` | `{}` | no |
| <a name="input_client_machine_type"></a> [client\_machine\_type](#input\_client\_machine\_type) | GCP machine type. ie. c2-standard-16 | `string` | `"c2-standard-16"` | no |
| <a name="input_client_mig_name"></a> [client\_mig\_name](#input\_client\_mig\_name) | MIG name | `string` | `"daos-client"` | no |
| <a name="input_client_number_of_instances"></a> [client\_number\_of\_instances](#input\_client\_number\_of\_instances) | Number of daos clients to bring up | `number` | `4` | no |
| <a name="input_client_os_disk_size_gb"></a> [client\_os\_disk\_size\_gb](#input\_client\_os\_disk\_size\_gb) | OS disk size in GB | `number` | `20` | no |
| <a name="input_client_os_disk_type"></a> [client\_os\_disk\_type](#input\_client\_os\_disk\_type) | OS disk type ie. pd-ssd, pd-standard | `string` | `"pd-ssd"` | no |
| <a name="input_client_os_family"></a> [client\_os\_family](#input\_client\_os\_family) | OS GCP image family | `string` | `"daos-client-hpc-centos-7"` | no |
| <a name="input_client_os_project"></a> [client\_os\_project](#input\_client\_os\_project) | OS GCP image project name. Defaults to project\_id if null. | `string` | `null` | no |
| <a name="input_client_preemptible"></a> [client\_preemptible](#input\_client\_preemptible) | If preemptible instances | `string` | `false` | no |
| <a name="input_client_service_account"></a> [client\_service\_account](#input\_client\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string,<br>    scopes = set(string)<br>  })</pre> | <pre>{<br>  "email": null,<br>  "scopes": [<br>    "https://www.googleapis.com/auth/devstorage.read_only",<br>    "https://www.googleapis.com/auth/logging.write",<br>    "https://www.googleapis.com/auth/monitoring.write",<br>    "https://www.googleapis.com/auth/servicecontrol",<br>    "https://www.googleapis.com/auth/service.management.readonly",<br>    "https://www.googleapis.com/auth/trace.append",<br>    "https://www.googleapis.com/auth/cloud-platform"<br>  ]<br>}</pre> | no |
| <a name="input_client_template_name"></a> [client\_template\_name](#input\_client\_template\_name) | MIG template name | `string` | `"daos-client"` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the GCP network to use | `string` | `"default"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project to use | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region to create and test resources in | `string` | n/a | yes |
| <a name="input_server_daos_crt_timeout"></a> [server\_daos\_crt\_timeout](#input\_server\_daos\_crt\_timeout) | crt\_timeout | `number` | `300` | no |
| <a name="input_server_daos_disk_count"></a> [server\_daos\_disk\_count](#input\_server\_daos\_disk\_count) | Number of local ssd's to use | `number` | `16` | no |
| <a name="input_server_daos_disk_type"></a> [server\_daos\_disk\_type](#input\_server\_daos\_disk\_type) | Daos disk type to use. For now only suported one is local-ssd | `string` | `"local-ssd"` | no |
| <a name="input_server_daos_scm_size"></a> [server\_daos\_scm\_size](#input\_server\_daos\_scm\_size) | scm\_size | `number` | `200` | no |
| <a name="input_server_gvnic"></a> [server\_gvnic](#input\_server\_gvnic) | Use Google Virtual NIC (gVNIC) network interface | `bool` | `false` | no |
| <a name="input_server_instance_base_name"></a> [server\_instance\_base\_name](#input\_server\_instance\_base\_name) | MIG instance base names to use | `string` | `"daos-server"` | no |
| <a name="input_server_labels"></a> [server\_labels](#input\_server\_labels) | Set of key/value label pairs to assign to daos-server instances | `any` | `{}` | no |
| <a name="input_server_machine_type"></a> [server\_machine\_type](#input\_server\_machine\_type) | GCP machine type. ie. e2-medium | `string` | `"n2-custom-36-215040"` | no |
| <a name="input_server_mig_name"></a> [server\_mig\_name](#input\_server\_mig\_name) | MIG name | `string` | `"daos-server"` | no |
| <a name="input_server_number_of_instances"></a> [server\_number\_of\_instances](#input\_server\_number\_of\_instances) | Number of daos servers to bring up | `number` | `4` | no |
| <a name="input_server_os_disk_size_gb"></a> [server\_os\_disk\_size\_gb](#input\_server\_os\_disk\_size\_gb) | OS disk size in GB | `number` | `20` | no |
| <a name="input_server_os_disk_type"></a> [server\_os\_disk\_type](#input\_server\_os\_disk\_type) | OS disk type ie. pd-ssd, pd-standard | `string` | `"pd-ssd"` | no |
| <a name="input_server_os_family"></a> [server\_os\_family](#input\_server\_os\_family) | OS GCP image family | `string` | `"daos-server-centos-7"` | no |
| <a name="input_server_os_project"></a> [server\_os\_project](#input\_server\_os\_project) | OS GCP image project name. Defaults to project\_id if null. | `string` | `null` | no |
| <a name="input_server_pools"></a> [server\_pools](#input\_server\_pools) | List of pools and containers to be created | <pre>list(object({<br>    name       = string<br>    size       = string<br>    tier_ratio = number<br>    user       = string<br>    group      = string<br>    acls       = list(string)<br>    properties = map(any)<br>    containers = list(object({<br>      name            = string<br>      type            = string<br>      user            = string<br>      group           = string<br>      acls            = list(string)<br>      properties      = map(any)<br>      user_attributes = map(any)<br>    }))<br>  }))</pre> | `[]` | no |
| <a name="input_server_preemptible"></a> [server\_preemptible](#input\_server\_preemptible) | If preemptible instances | `string` | `false` | no |
| <a name="input_server_service_account"></a> [server\_service\_account](#input\_server\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string,<br>    scopes = set(string)<br>  })</pre> | <pre>{<br>  "email": null,<br>  "scopes": [<br>    "https://www.googleapis.com/auth/devstorage.read_only",<br>    "https://www.googleapis.com/auth/logging.write",<br>    "https://www.googleapis.com/auth/monitoring.write",<br>    "https://www.googleapis.com/auth/servicecontrol",<br>    "https://www.googleapis.com/auth/service.management.readonly",<br>    "https://www.googleapis.com/auth/trace.append",<br>    "https://www.googleapis.com/auth/cloud-platform"<br>  ]<br>}</pre> | no |
| <a name="input_server_template_name"></a> [server\_template\_name](#input\_server\_template\_name) | MIG template name | `string` | `"daos-server"` | no |
| <a name="input_subnetwork_name"></a> [subnetwork\_name](#input\_subnetwork\_name) | Name of the GCP sub-network to use | `string` | `"default"` | no |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The GCP project where the subnetwork is defined | `string` | `null` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | The GCP zone to create and test resources in | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
