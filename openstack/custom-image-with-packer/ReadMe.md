# Steps to Create a Custom OpenStack Image with Packer

- [Steps to Create a Custom OpenStack Image with Packer](#steps-to-create-a-custom-openstack-image-with-packer)
  - [Packer Installed:](#packer-installed)
  - [OpenStack CLI Installed:](#openstack-cli-installed)
  - [Installation openstack plugin](#installation-openstack-plugin)
  - [Source OpenStack Credentials](#source-openstack-credentials)
  - [Gather Required IDs](#gather-required-ids)
  - [Initialize Packer](#initialize-packer)
  - [Validate the Configuration](#validate-the-configuration)
  - [Build the Image](#build-the-image)

## Packer Installed:
Download and install Packer from the official website. For example, on a Linux system

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer
packer --version
```

## OpenStack CLI Installed:
Install the OpenStack command-line client (`python-openstackclient`) to query `image`, `flavor`, `network` IDs, and etc. For example

```bash
python3 -m venv venv3
source venv3/bin/activate
pip install --upgrade pip
pip install python-openstackclient
```

## Installation openstack plugin
To install this plugin, copy and paste this code into your Packer configuration . Then, run packer init.
```bash
packer {
  required_plugins {
    openstack = {
      version = "~> 1"
      source  = "github.com/hashicorp/openstack"
    }
  }
}
```
Alternatively, you can use packer plugins install to manage installation of this plugin.
```bash
packer plugins install github.com/hashicorp/openstack
```

## Source OpenStack Credentials

Download your `admin-openrc.sh` file from your OpenStack provider’s control panel (e.g., under the OpenStack menu).
Source the credentials to set environment variables:
```bash
source /etc/kolla/admin-openrc.sh
```
This sets variables like `OS_USERNAME`, `OS_PASSWORD`, `OS_AUTH_URL`, `OS_TENANT_ID`, etc.


## Gather Required IDs
You’ll need the IDs for the source `image`, `flavor`, and `network`, etc. Use the OpenStack CLI to retrieve them:

```bash
## Get Source Image ID (e.g., Debian12)
SOURCE_ID=$(openstack image list -f json | jq -r '.[] | select(.Name == "Debian12") | .ID')
echo $SOURCE_ID

## Get Flavor ID (e.g., Small)
FLAVOR_ID=$(openstack flavor list -f json | jq -r '.[] | select(.Name == "Small") | .ID')
echo $FLAVOR_ID

## Get Network ID (e.g., public network)
NETWORK_ID=$(openstack network list -f json | jq -r '.[] | select(.Name == "Public") | .ID')
echo $NETWORK_ID

## Get Volume Type Name 
VOLUME_TYPE_NAME=$(openstack volume type list -f value -c 'Name')
echo $VOLUME_TYPE_NAME

## Get Security Group Name 
SECURITY_GROUP_NAME=$(openstack security group list --project admin -f value -c 'Name')
echo $SECURITY_GROUP_NAME

## Get Volume Availability Zone  
VOLUME_AVAILABILITY_ZONE_NAME=$(openstack availability zone list --volume -f value -c 'Zone Name')
echo $VOLUME_AVAILABILITY_ZONE_NAME
```

## Initialize Packer
Initialize the Packer environment to install the OpenStack plugin:
```bash
packer init sample.pkr.hcl
```

## Validate the Configuration
Check the template for errors:
```bash
packer validate sample.pkr.hcl
```
If valid, you’ll see a message like **The configuration is valid.**

## Build the Image
Run the build command to create the image:
```bash
packer build sample.pkr.hcl
```