# Images

This directory contains files necessary for building DAOS images using [Cloud Build](https://cloud.google.com/build) and [Packer](https://developer.hashicorp.com/packer/downloads).

## Pre-Deployment steps required

If you have not done so yet, please complete the steps in [Pre-Deployment Guide](../docs/pre-deployment_guide.md).

The pre-deployment steps will have you run the `images/build.sh` script once in order to build a DAOS server image and a DAOS client image with the configured default settings.

That should be all you need to run the Terraform examples in the `terraform/examples` directory or to run the [DAOS examples in the Google HPC Toolkit](https://github.com/GoogleCloudPlatform/hpc-toolkit/tree/main/community/examples/intel).

The information in this document is provided in case you need to build custom images with non-default settings.

## Building DAOS images

To rebuild the images with the default settings run:

```bash
cd images
./build.sh
```

## The Packer HCL template file

A single Packer HCL template file `daos.pkr.hcl` is used to build either a DAOS server or DAOS client image.

The `daos.pkr.hcl` file does not build both server and client images in a single `packer build` run. This is by design since there are use cases in which only one type of image is needed. If both types of images are needed, then `packer build` must be run twice with different variable values.

### Source Block

Within the `daos.pkr.hcl` template there is a single `source` block. Most of the settings for the block are set by variable values.

### Build Block

The `build` block consists of provisioners that do the following:

1. Install Ansible
2. Run the `ansible_playbooks/tune.yml` playbook
3. Run the `ansible_playbooks/daos.yml` playbook

These provisioners are the same for building both DAOS server and DAOS client images.

The `daos_install_type` variable in the `daos.pkr.hcl` template is passed in the `--extra-vars` parameter when running the `daos.yml` ansible playbook.

If `daos_install_type=server`, then the `daos.yml` playbook will install the DAOS server packages.

If `daos_install_type=client`, then the `daos.yml` playbook will install the DAOS client packages.

## `build.sh` environment variables

The `images/build.sh` script uses the following environment variables.

| Environment Variable         | Description                                                |
| ---------------------------- | ---------------------------------------------------------- |
| GCP_PROJECT                  | Google Cloud Project ID                                    |
| GCP_ZONE                     | Zone where images will be deployed                         |
| GCP_BUILD_WORKER_POOL        | Google Cloud Build Worker Pool                             |
| GCP_USE_IAP                  | Use Identity Aware Proxy                                   |
| GCP_ENABLE_OSLOGIN           | Enable os-login                                            |
| GCP_USE_CLOUDBUILD           | Run packer in a Cloud Build job                            |
| GCP_CONFIGURE_PROJECT        | Configure default service acct for Cloud Build             |
| DAOS_VERSION                 | Version of DAOS to install                                 |
| DAOS_REPO_BASE_URL           | Base URL of DAOS Repository                                |
| DAOS_PACKAGES_REPO_FILE      | See "Controlling the version of DAOS to be installed"      |
| DAOS_MACHINE_TYPE            | The machine type to use for the image                      |
| DAOS_SOURCE_IMAGE_FAMILY     | Source image family that Packer will use as the base image |
| DAOS_SOURCE_IMAGE_PROJECT_ID | Source project id that contains the source image           |
| DAOS_SERVER_IMAGE_FAMILY     | Name of the image family for the DAOS Server image         |
| DAOS_CLIENT_IMAGE_FAMILY     | Name of the image family for the DAOS Client image         |
| DAOS_BUILD_SERVER_IMAGE      | Whether or not build the DAOS Server image                 |
| DAOS_BUILD_CLIENT_IMAGE      | Whether or not build the DAOS Client image                 |
| DAOS_PACKER_TEMPLATE         | Name of the Packer template                                |

To view the default values for these variables see the defaults set in the `build.sh` script.

Running `build.sh --help` will display the values of these variables so that you can inspect them before running `build.sh`

### Controlling the version of DAOS to be installed

Official DAOS packages are hosted at https://packages.daos.io/

Unfortunately, the paths to the `.repo` files for each repository do not follow a standard convention that can be dynamically created based on something like the `/etc/os-release` file.

To specify the path to a repo file the following 3 environment variables are used:

- `DAOS_REPO_BASE_URL`
- `DAOS_VERSION`
- `DAOS_PACKAGES_REPO_FILE`

These files are used to build the url to the `daos_packages.repo` file.

```
"${DAOS_REPO_BASE_URL}/v${DAOS_VERSION}/${DAOS_PACKAGES_REPO_FILE}
```

The values of these variables should not start or end with a `/`

**Examples:**

  To install DAOS v2.2.0 on CentOS 7

  ```bash
  DAOS_REPO_BASE_URL=https://packages.daos.io
  DAOS_VERSION="2.2.0"
  DAOS_PACKAGES_REPO_FILE="CentOS7/packages/x86_64/daos_packages.repo"
  ```

  To install DAOS v2.2.0 on Rocky 8

  ```bash
  DAOS_REPO_BASE_URL=https://packages.daos.io
  DAOS_VERSION="2.2.0"
  DAOS_PACKAGES_REPO_FILE="EL8/packages/x86_64/daos_packages.repo"
  ```

## Building only the DAOS Server or the DAOS Client image

If you do not want to build one of the images, you must set the appropriate environment variable.

For example,

To build only the DAOS Server image

```bash
cd images
export DAOS_BUILD_CLIENT_IMAGE="false"  # Do not run the job to build the DAOS client image
./build.sh
```

To build only the DAOS Client image

```bash
cd images
export DAOS_BUILD_SERVER_IMAGE="false" # Do not run the job to build the DAOS server image
./build.sh
```

## Custom image builds

To create images that do not use the default settings, export one or more of the environment variables listed above before running `build.sh`

### Change the name of the image family

```bash
cd images
export DAOS_SERVER_IMAGE_FAMILY="my-daos-server"
export DAOS_CLIENT_IMAGE_FAMILY="my-daos-client"
./build.sh
```

### Use a different source image

For the source image, use the `rocky-linux-8-optimized-gcp` community image instead of the `hpc-rocky-linux-8` image.

```bash
cd images
export DAOS_SOURCE_IMAGE_FAMILY="rocky-linux-8-optimized-gcp"
export DAOS_SOURCE_IMAGE_PROJECT_ID="rocky-linux-cloud"
./build.sh
```

### Other Scenarios

Say you want to make the following customizations to the images:

1. Change the image family names of the DAOS Server and DAOS Client images
2. Use `hpc-rocky-linux-8` as the source image for the DAOS client image (the default).
3. Use `rocky-linux-8-optimized-gcp` as the source image for the DAOS server image.

In this scenario it will be necessary to run the `build.sh` script two times with
different environment variables.

**Build Client Image**

```bash
cd images
export DAOS_BUILD_CLIENT_IMAGE="true"
export DAOS_CLIENT_IMAGE_FAMILY="daos-client"

export DAOS_BUILD_SERVER_IMAGE="false"
./build.sh
```

**Build Server Image**

```bash
cd images
export DAOS_BUILD_CLIENT_IMAGE="false"         # Do not build client image
export DAOS_BUILD_SERVER_IMAGE="true"          # Build server image
export DAOS_SERVER_IMAGE_FAMILY="daos-server"  # Change image family name for the server image
export DAOS_SOURCE_IMAGE_FAMILY="rocky-linux-8-optimized-gcp" # Change source image family
export DAOS_SOURCE_IMAGE_PROJECT_ID="rocky-linux-cloud"       # Change source image project
./build.sh
```

## Running packer locally (Do not use Cloud Build)

Set `GCP_USE_CLOUDBUILD="false"` to run `packer` locally instead of running it in a Cloud Build job.

```bash
cd images
export GCP_USE_CLOUDBUILD="false" # Do not run packer in Cloud Build
./build.sh
```

When running `build.sh` this way, all project configuration steps are skipped.

When `GCP_USE_CLOUDBUILD="true"` the `build.sh` will check your GCP project to ensure the default service account has the proper permissions needed for the Cloud Build job to run packer and create the images in your project.  Setting `GCP_USE_CLOUDBUILD="true"` will skip the project configuration steps. In this case, it's up to you to make sure the proper permissions are configured for you to run packer locally to build the images.
