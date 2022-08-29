#!/bin/bash

# upgrade kernel to 5.10
cd /tmp/

wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.10/amd64/linux-headers-5.10.0-051000_5.10.0-051000.202012132330_all.deb

wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.10/amd64/linux-headers-5.10.0-051000-generic_5.10.0-051000.202012132330_amd64.deb

wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.10/amd64/linux-image-unsigned-5.10.0-051000-generic_5.10.0-051000.202012132330_amd64.deb

wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.10/amd64/linux-modules-5.10.0-051000-generic_5.10.0-051000.202012132330_amd64.deb

sudo dpkg -i *.deb

# get firecraker binary
release_url="https://github.com/firecracker-microvm/firecracker/releases"
latest=$(basename $(curl -fsSLI -o /dev/null -w  %{url_effective} ${release_url}/latest))
arch=`uname -m`
curl -L ${release_url}/download/${latest}/firecracker-${latest}-${arch}.tgz \
| tar -xz

mv release-${latest}-$(uname -m)/firecracker-${latest}-$(uname -m) firecracker

# run fire craker
sudo setfacl -m u:${USER}:rw /dev/kvm
rm -f /tmp/firecracker.socket
./firecracker --api-sock /tmp/firecracker.socket