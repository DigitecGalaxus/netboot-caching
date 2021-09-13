# Netboot Caching Server

This caching server is a locally deployable extension to the [netboot server](https://github.com/DigitecGalaxus/netboot), which caches assets for network booting. It caches the assets which are delivered via [HTTP](https://github.com/DigitecGalaxus/netboot/tree/main/netboot-services/http) only. This speeds up network boots in one network.

The caching server itself is designed to be network booted, a squashfs file is built for this reason.

The caching server runs a Docker daemon and an Nginx container, which serves the files which are present in an assets folder. The idea is that the netboot server knows about it's caching servers and pushes the files onto it with the [syncer functionality](https://github.com/DigitecGalaxus/netboot/tree/main/netboot-services/sync) (using `rsync` with an SSH connection). Therefore the caching functionality of Nginx is not used, as all files are available locally.

[![Build Status](https://digitecgalaxus.visualstudio.com/SystemEngineering/_apis/build/status/caching-server?branchName=main)](https://digitecgalaxus.visualstudio.com/SystemEngineering/_build/latest?definitionId=1184&branchName=main)

## Prerequisites

- A docker host to build it manually or access to Azure DevOps to build it automatically with the [azure-pipelines.yml](azure-pipelines.yml) file.
- The docker image named `anymodconrst001dg.azurecr.io/planetexpress/squashfs-tools:latest`, the image which results from the build of the [squashfs-tools repository](https://github.com/DigitecGalaxus/squashfs-tools). The idea is that you follow the Usage section of the squashfs-tools repository and have the docker image available locally.
- The docker image named `anymodconrst001dg.azurecr.io/planetexpress/ubuntu-base:21.04`, the image which results from the build of the [ubuntu-base repository](https://github.com/DigitecGalaxus/ubuntu-base). The idea is that you follow the Usage section of the ubuntu-base repository and have the docker image available locally.

## State considerations

The caching-server boots via iPXE too. But as it caches (hence "caching-server") all squashfs-images (including it's own), the iPXE menu for the caching server is configured such that it boots the squashfs file located on it's own harddisk. Still, this boot is stateless: The whole image is loaded to RAM and thereafter no disk access is necessary to run the OS.


After booting up, the disk will be mounted to the location where the squashfs-images are accessible to be kept up-to-date.

So the caching-server will load the most recent image when booting. When booted, the synchronization of the main netboot server makes sure that all images are up-to-date.


## How to add caching-servers

### General setup for caching servers

To prepare access to the caching servers, generate a private key and the corresponding public key, e.g. using openssl/ssh-keygen and add the public key to the authorized_keys file. Note that this will overwrite the sample public key in this repository.

```sh
openssl genrsa -out  $(pwd)/cachingserver.pem
openssl rsa -in $(pwd)/cachingserver.pem -pubout > cachingserver.pub
echo "$(ssh-keygen -f cachingserver.pub -i -mPKCS8) remote-mgmt-keypair" > $(pwd)/fs/authorized_keys
```

To build the squashfs file that the caching servers boot, execute the build script and pass the parameters according to the setup of the [netboot server](https://github.com/DigitecGalaxus/netboot). These details are needed to publish the squashfs and update IPXE menus on the netboot server. Check the prerequisites of the netboot server README.

```sh
# netbootPrivateKeyPath is the path to the private key of the netboot server, that hosts the squashfs files and menus
# The scp connection is composed of the first three arguments, the last is a path on the netboot server itself, where assets are be stored
# The default of the netbootAssetsDirectory is the $HOME/netboot/assets directory, where $HOME is the home directory of the netbootUsername user on the netboot server.
./build.sh netbootPrivateKeyPath netbootIP netbootUsername netbootAssetsDirectory
```

The output of the build script will be a file named `netboot-caching-server.squashfs`, which is `scp`'d to the netboot server into the netbootAssetsDirectory.

### Individual setup per caching server

Apart from setting up a caching server physically in the target network (16GB RAM; optional SSD), the following tasks have to be done for each caching server:

- Make sure the host has a static IP or a DCHP reservation in the target network. This IP should be added to the [caching server list](https://github.com/DigitecGalaxus/netboot/blob/main/netboot-services/cachingServerFetcher/caching_server_list.json)
- Ensure that the device uses network boot (BIOS settings) and boots the caching server squashfs. Booting the right squashfs can be done with a MAC specific IPXE file on the netboot server. This MAC specific file is automatically created by the [IPXE Menu Generator](https://github.com/DigitecGalaxus/netboot/tree/main/netboot-services/ipxeMenuGenerator)
- Add the caching server into the IPXE menu to ensure that clients in the network of the caching server use it to access the netboot assets.
TODO: link to the file on github / or move the menu generation into the ipxe menu generator
- Once the caching server is online: Trigger a synchronization on the files that need to be synchronized to this caching server, e.g. by `touch`ing them.
TODO: link to the complete `rsync` command in the netboot README, once the [PR 2](https://github.com/DigitecGalaxus/netboot/pull/2) is merged

## How to configure a local stateful disk to cache assets

In case of a power outage it could become critical when all clients (including the caching-server) try to boot from the network simultaneously. Therefore a local disk can be added to cache both the caching-server squashfs and images for thinclients. The disk needs to have two partitions.

_Note: This is a manual process._

Make sure to follow the following steps:

1. Install an internal disk (you can use NVMe, SATA or VirtIO disks).
2. Clean the partition table using `dd if=/dev/random of=/dev/<disk>` and wait for couple of seconds to wipe it properly.
3. Create a new partition table using `fdisk /dev/<disk>` and choose GPT as partition table layout as well as Linux Filesystem as the type for the **two** partitions you're creating: The first one with 1GB and the second one with the remaining available space. Make sure to write the changes to the disk.
4. Format both partitions with ext4 using `mkfs.ext4 /dev/<partition>`. After that, restart the automounter: `systemctl restart automounter.service`.
5. Now trigger a complete resync from the netboot server.
6. Change the Caching-Server ipxe to boot from the local disk inside the netboot repository.

You're done setting up a stateful disk.

## Contribute

No matter how small, we value every contribution! If you wish to contribute,

1. Please create an issue first - this way, we can discuss the feature and flesh out the nitty-gritty details
2. Fork the repository, implement the feature and submit a pull request
3. Your feature will be added once the pull request is merged
