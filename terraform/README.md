# Terraform deployment of Distributed Asynchronous Object Storage (DAOS) on Google Cloud Platform (GCP)

This directory contains Terraform code to deploy DAOS on GCP.

This module consists of a collection of Terraform submodules to deploy DAOS client and server instances on GCP.
Below is the list of available submodules:

* [DAOS Server](modules/daos_server)
* [DAOS Client](modules/daos_client)

The [main.tf](main.tf) file contains the main set of configuration and uses submodules to deploy DAOS server and client instances on GCP.

## Usage

Configure [daos.tfvars](daos.tfvars) file to your needs, then run below commands to deploy DAOS:

```
terraform init -input=false
terraform plan -out=tfplan -input=false -var-file="daos.tfvars"
terraform apply -input=false tfplan
```

To destroy DAOS environment, use below command:

```
terraform destroy -auto-approve -var-file="daos.tfvars"
```

## Compatibility

This module is meant to use with Terraform 0.14.

## Examples

[examples](examples) directory contains Terraform code of how to use these particular submodules.
