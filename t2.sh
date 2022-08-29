#!/bin/bash
# build kernel
config="resources/guest_configs/microvm-kernel-x86_64-5.10.config"
./tools/devtool build_kernel -c $config -n 8

cp build/kernel/linux-5.10/vmlinux-5.10-x86_64.bin ~/hello-vmlinux.bin

# build rootfs
./tools/devtool build_rootfs -s 4096MB
cp build/rootfs/bionic.rootfs.ext4 ~/hello-rootfs.ext4

sudo mkdir /mnt/rootfs
sudo mount ~/hello-rootfs.ext4 /mnt/rootfs
sudo cp ~/vbenchmark /mnt/rootfs/opt/

# set guest kernel
arch=`uname -m`
kernel_path=$(pwd)"/hello-vmlinux.bin"

if [ ${arch} = "x86_64" ]; then
    curl --unix-socket /tmp/firecracker.socket -i \
      -X PUT 'http://localhost/boot-source'   \
      -H 'Accept: application/json'           \
      -H 'Content-Type: application/json'     \
      -d "{
            \"kernel_image_path\": \"${kernel_path}\",
            \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off\"
       }"
elif [ ${arch} = "aarch64" ]; then
    curl --unix-socket /tmp/firecracker.socket -i \
      -X PUT 'http://localhost/boot-source'   \
      -H 'Accept: application/json'           \
      -H 'Content-Type: application/json'     \
      -d "{
            \"kernel_image_path\": \"${kernel_path}\",
            \"boot_args\": \"keep_bootcon console=ttyS0 reboot=k panic=1 pci=off\"
       }"
else
    echo "Cannot run firecracker on $arch architecture!"
    exit 1
fi

# set the guest rootfs
rootfs_path=$(pwd)"/hello-rootfs.ext4"
curl --unix-socket /tmp/firecracker.socket -i \
  -X PUT 'http://localhost/drives/rootfs' \
  -H 'Accept: application/json'           \
  -H 'Content-Type: application/json'     \
  -d "{
        \"drive_id\": \"rootfs\",
        \"path_on_host\": \"${rootfs_path}\",
        \"is_root_device\": true,
        \"is_read_only\": false
   }"

# set guest network
sudo ip tuntap add tapvm1 mode tap
sudo ip addr add 10.0.0.1/24 dev tapvm1
sudo ip link set tapvm1 up
sudo iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i tapvm1 -o ens3 -j ACCEPT

curl --unix-socket /tmp/firecracker.socket \
  -X PUT 'http://localhost/network-interfaces/eth0' \
  -H 'accept:application/json' \
  -H 'Content-Type:application/json' \
  -d '{
    "iface_id": "eth0",
    "guest_mac": "AA:FC:00:00:00:01",
    "host_dev_name": "tapvm1"
  }'

# set resources
curl --unix-socket /tmp/firecracker.socket -i  \
  -X PUT 'http://localhost/machine-config' \
  -H 'Accept: application/json'            \
  -H 'Content-Type: application/json'      \
  -d '{
      "vcpu_count": 4,
      "mem_size_mib": 8192
  }'

# start instance
curl --unix-socket /tmp/firecracker.socket -i \
  -X PUT 'http://localhost/actions'       \
  -H  'Accept: application/json'          \
  -H  'Content-Type: application/json'    \
  -d '{
      "action_type": "InstanceStart"
   }'

# set micro-vm network
ip route flush dev eth0
ip addr add 10.0.0.2/24 dev eth0
ip route add 10.0.0.0/24 dev eth0
ip route add 0.0.0.0/0 via 10.0.0.1