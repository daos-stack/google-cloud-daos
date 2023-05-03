# terraform/examples/io500/images

This directory contains content for building DAOS Server and Client images used in IO500 benchmark runs.

The `build_io500_images.sh` script makes modifications in the `images\` directory and then calls `images/build.sh` to build images.

Specifically, it does the following:

- Copies the `terraform/examples/io500/images/ansible_playbooks/io500.yml` playbook to `images/ansible_playbooks`
- Copies the `terraform/examples/io500/images/patches` directory to `images/`
- Creates an `io500-daos.pkr.hcl` packer template. The template includes an additional ansible-local provisioner that runs the io500.yml playbook when building the DAOS client image.
- Calls `images/build.sh` to build the DAOS client and server images
  - When building the client image sets the DAOS_PACKER_TEMPLATE=`io500-daos.pkr.hcl` which installs the  DAOS client image

The `build_io500_images.sh` script will build 2 images with image families:

- `daos-client-io500-rocky-8`
- `daos-server-io500-rocky-8`
