#!/bin/bash
set -eu

if [[ $# -lt 4 ]]; then
        echo "Error: Too few arguments passed to script"
        exit 1
else
        netbootPrivateKeyPath="$1"
        netbootIP="$2"
        netbootUsername="$3"
        netbootAssetsDirectory="$4"
fi

# Building actual image.
echo ">>>Building image"
# Used to invalidate the Docker build cache
date >date.txt
docker image build -t netboot-caching-server .
echo ">>>Running image"
containerID=$(docker run -d netboot-caching-server tail -f /dev/null)
echo ">>>Tarring container contents"
docker cp "$containerID:/" - >newfilesystemcaching.tar
echo ">>>Deleting container"
docker rm -f "$containerID"
echo ">>>Generating SquashFS"
containerID=$(docker run -d -v "$(pwd)/newfilesystemcaching.tar:/var/live/newfilesystem.tar" anymodconrst001dg.azurecr.io/planetexpress/squashfs-tools:latest /bin/sh -c "tar2sqfs --quiet newfilesystem.squashfs < /var/live/newfilesystem.tar")
docker wait "$containerID"
echo ">>>Exporting SquashFS"
docker cp "$containerID:/var/live/newfilesystem.squashfs" ./new.squashfscaching
echo ">>>Uploading SquashFS"
scp -o 'StrictHostKeyChecking=no' -i "$netbootPrivateKeyPath" ./new.squashfscaching "$netbootUsername@$netbootIP:$netbootAssetsDirectory/caching-server/netboot-caching-server.squashfs"
echo ">>>Cleaning up"
docker rm -f "$containerID"
rm -f "$(pwd)"/newfilesystemcaching.tar
rm -f ./new.squashfscaching
