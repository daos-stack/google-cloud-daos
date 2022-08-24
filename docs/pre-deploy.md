# Pre-Deployment Instructions

## Overview

To deploy DAOS on GCP

  - You need a [Google Cloud](https://cloud.google.com/) account and a [project](https://cloud.google.com/resource-manager/docs/creating-managing-projects).
  - Your GCP project must have enough Compute Engine [quota](https://cloud.google.com/compute/quotas) to run the examples in this repository
  - If you decide not to use Cloud Shell, you must have a Linux or macOS terminal with the required dependencies installed
  - You must configure the [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/gcloud) with a default project, region and zone
  - You must have a Cloud NAT
  - You must have DAOS server and client images

After completing the following instructions you will be ready to deploy DAOS.

## Create a GCP Project

When you create a Google Cloud account a project named "My First Project" will be created for you. The project will have a randomly generated ID.

Since *project name* and *project ID* are used in many configurations it is recommended that you create a new project specifically for your DAOS deployment or solution that will include DAOS.

To create a project, refer to the following documentation

- [Get Started with Google Cloud](https://cloud.google.com/docs/get-started)
- [Creating and managing projects](https://cloud.google.com/resource-manager/docs/creating-managing-projects)

Make note of the *Project Name* and *Project ID* for the project that you plan to use for your DAOS deployment as you will be using it later in various configurations.

---

**NOTE**

Some organizations require that GCP accounts and projects be created by a centralized IT department.

Depending on your organization you may need to make an internal request for access to GCP and ownership of a GCP project.

Often in these scenarios the projects have restrictions on service usage, networking, IAM, etc.in order to control costs and/or meet the security requirements of the organization. Such restrictions can sometimes result in failed deployments of DAOS.

If your project was created for you by your organization and you experience issues with the examples in this repo, it may be necessary to work with your organization to understand what changes can be made in your project to ensure a successful deployment of DAOS.

---

## Determine Region and Zone for Deployment

Determine the region and zone for your DAOS deployment.

See [Regions and Zones](https://cloud.google.com/compute/docs/regions-zones).

Make a note of your chosen region and zone as you will be using this information later.

## Terminal Selection and Software Installation

Decide which terminal you will use and start a session.

- **Cloud Shell**

  [Cloud Shell](https://cloud.google.com/shell) is an online development and operations environment accessible anywhere with your browser. You can manage your resources with its online terminal preloaded with utilities such as `git` and the `gcloud` command-line tool.

  With [Cloud Shell](https://cloud.google.com/shell) you do not need to install any software.

  Everything you need to deploy DAOS with the examples in this repository or with the [Cloud HPC Toolkit](https://cloud.google.com/hpc-toolkit) is already installed.

  Using [Cloud Shell](https://cloud.google.com/shell) is by far the easiest way to get started with DAOS on GCP.

  Depending on how you found this documentation you may already be viewing this content in a Cloud Shell tutorial. If so, you can click the next button at the bottom of the tutorial panel to continue.

  Otherwise, if you would like to open Cloud Shell in your browser, [click here](https://shell.cloud.google.com/?show=terminal&show=ide&environment_deployment=ide)

  ---

  **NOTE**
  Cloud Shell can run in Ephemeral Mode which does not persist storage. This has caused some confusion to some who are new to Cloud Shell since any changes made are not persisted across sessions. For more info, see  [Choose ephemeral mode](https://cloud.google.com/shell/docs/using-cloud-shell#choosing_ephemeral_mode).

  ---

- **Remote Cloud Shell**

  You may be thinking "I don't want to work in a browser!"

  With Cloud Shell you aren't forced to use a browser.

  If you [install the Google Cloud CLI](https://cloud.google.com/sdk/docs/install) on your system, you can use the [`gcloud cloud-shell ssh`](https://cloud.google.com/sdk/gcloud/reference/cloud-shell/ssh) command to launch an interactive Cloud Shell SSH session from your favorite terminal.

  This allows you to use your local terminal with the benefit of having the software dependencies already installed in Cloud Shell.

- **Local**

  Throughout the documentation in this repository, the term "local terminal" will refer to any terminal that is not Cloud Shell.

  The terminal may be on your system, a remote VM or bare metal machine, Docker container, etc.

  If you choose to use a *local* terminal, you will need to install the following dependencies.

  - [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
  - [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)

  If you plan to deploy DAOS with the Cloud HPC Toolkit, see the [Install dependencies](https://cloud.google.com/hpc-toolkit/docs/setup/install-dependencies) documentation for additional dependencies.

## Google Cloud CLI (`gcloud`) Configuration

Many of the bash scripts and Terraform configurations in this repository assume that you have set a default project, region and zone in your active `gcloud` configuration.

To configure `gcloud` run

```bash
# Create a named configuration and make it the active config
gcloud config configurations create <config name> --activate

# Initialize it
gcloud init --console-only

# Set your default project
gcloud config set core/project <project name>

# Set your default region
gcloud config set compute/region <region>

# Set your default zone
gcloud config set compute/zone <zone>

# Verify
gcloud config list
gcloud config configurations list --filter="IS_ACTIVE=True"

# Authorize
gcloud auth login
```

For more information see the various [How-to Guides](https://cloud.google.com/sdk/docs/how-to) for the Google Cloud CLI.

The commands shown in the documentation will work in [Cloud Shell](https://cloud.google.com/shell) or a *local* terminal.

## Quotas

Google Compute Engine enforces quotas on resources to prevent unforseen spikes in usage.

In order to deploy DAOS with the examples in this repository or the [community examples in the Google Cloud HPC Toolkit](https://github.com/GoogleCloudPlatform/hpc-toolkit/tree/main/community/examples/intel) you must have enough [quota](https://cloud.google.com/compute/quotas) for the region in which you are deploying.

Understanding the quota for a single DAOS server and client instance will allow you to calculate the quota needed to deploy DAOS clusters of varying sizes.

**Required quota for a single DAOS client instance**

```
Service             Quota                     Limit
------------------  ------------------------- ------
Compute Engine API  C2 CPUs                   16
Compute Engine API  Persistent Disk SSD (GB)  20GB
```

**Required quota for a single DAOS server instance**

```
Service             Quota                     Limit
------------------  ------------------------- ------
Compute Engine API  N2 CPUs                   36
Compute Engine API  Persistent Disk SSD (GB)  20GB
Compute Engine API  Local SSD (GB)            6TB
```

These quota limits are based on the machine types that are used in the examples as well as the maximum size and number of disks that can be attached to a server.

- DAOS Client: c2-standard-16 (16 vCPU, 64GB memory)
- DAOS Server: n2-custom-36-215040 (36 vCPU, 64GB memory)
- DAOS Server SSDs:
    Max number that can be attached to an instance = 16.
    Max size 375GB
    Quota Needed for 1 server: 16disks * 375GB = 6TB

So for the 4 server and 4 client examples in this repo you will need the following quotas

```
Service             Quota                     Limit  Description
------------------  ------------------------- ------ ------------------------------------------------------------------
Compute Engine API  C2 CPUs                   64     4 client instances * 16 = 64
Compute Engine API  N2 CPUs                   144    4 servers instances * 36 = 144
Compute Engine API  Persistent Disk SSD (GB)  160GB  (4 client instances * 20GB) + (4 server instances * 20GB) = 160GB
Compute Engine API  Local SSD (GB)            24TB   4 servers * (16 * 375GB disks) = 24TB
```

If your quotas do not at least have these minimum limits you will need to [request an increase](https://cloud.google.com/compute/quotas#requesting_additional_quota).

To view your current quotas you can go to https://console.cloud.google.com/iam-admin/quotas

You can also run

```bash
REGION=$(gcloud config get-value compute/region)

gcloud compute regions describe "${REGION}"
```

For more information, see [Quotas and Limits](https://cloud.google.com/compute/quotas)

## Enable APIs

Enable the service APIs which are used in a DAOS deployment.

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable networkmanagement.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable servicemanagement.googleapis.com
gcloud services enable sourcerepo.googleapis.com
gcloud services enable storage-api.googleapis.com
```

## Create a Cloud NAT

When deploying DAOS server and client instances external IPs are not added to the instances. The instances need to use services that are not accessible on the internal VPC default network as well as the https://packages.daos.io site for installs from DAOS repos.

Therefore, it is necessary to create a [Cloud NAT using Cloud Router](https://cloud.google.com/architecture/building-internet-connectivity-for-private-vms#create_a_nat_configuration_using_cloud_router).

First check to see if you already have a Cloud NAT for your region.

```bash
REGION=$(gcloud config get-value compute/region)

gcloud compute routers list --filter="region:${REGION}" --format="csv[no-heading,separator=' '](name)"
```

If the command returns a value, then you do not need to run the following commands, otherwise run

```bash
REGION=$(gcloud config get-value compute/region)

# Create a Cloud Router instance
gcloud compute routers create "nat-router-${REGION}" \
  --network default \
  --region "${REGION}"

# Configure the router for Cloud NAT
gcloud compute routers nats create nat-config \
  --router-region "${REGION}" \
  --router "nat-router-${REGION}" \
  --nat-all-subnet-ip-ranges \
  --auto-allocate-nat-external-ips
```

## Create Packer Image

DAOS images are built using Packer in Cloud Build.

In order to build DAOS images with Packer in Cloud Build, your GCP project must contain a Packer image.

Creating the Packer image only needs to be done once in the GCP project.

The Cloud Build service account requires the editor role.

Grant the editor role to the service account

```bash
PROJECT_ID=$(gcloud config get-value core/project)
CLOUD_BUILD_ACCOUNT=$(gcloud projects get-iam-policy

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "${CLOUD_BUILD_ACCOUNT}" \
  --role roles/compute.instanceAdmin
```

Build the Packer image

```bash
pushd ~/
git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git
cd cloud-builders-community/packer
gcloud builds submit .
rm -rf ~/cloud-builders-community
popd
```

## Build DAOS Images

Build the DAOS Server and Client images

```bash
pushd images
./build_images.sh --type all
popd
```

## Next Steps

You have completed the **Pre-Deployment** steps.

You are now ready to deploy DAOS on GCP.

For instructions, see [Deployment](deployment.md)
