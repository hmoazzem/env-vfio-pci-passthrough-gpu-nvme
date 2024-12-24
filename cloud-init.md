*[cloud-init](https://cloudinit.readthedocs.io) provides the necessary glue between launching a cloud [including local kvm VM] instance and connecting to it so that it works as expected.*

Ubuntu images seem to work best, so this example uses Ubuntu 24.04.

1. Download and prepare an Ubuntu 24.04 image

```sh
sudo curl -L https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
  -o /var/lib/libvirt/boot/noble-server-cloudimg-amd64.img
sudo cp /var/lib/libvirt/boot/noble-server-cloudimg-amd64.img /var/lib/libvirt/images/ubuntu2404-test-vm.qcow2
sudo qemu-img resize /var/lib/libvirt/images/ubuntu2404-test-vm.qcow2 120G # or whatever storage size you need
```

2. Create a cloud-init configuration file `cloud-init.conf.yaml`

```yaml
#cloud-config
groups:
- devel # example groups
users:
- name: examplerootuser
  sudo: ALL=(ALL) NOPASSWD:ALL
  groups: root
  lock_passwd: true
  shell: /bin/bash
  ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc_REST_OF_SSH_PUBKEY
packages:
- openssh-server
- wireguard
runcmd:
- umask 077
- wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
- |
  cat > /etc/wireguard/wg0.conf << EOF
  [Interface]
  PrivateKey = $(cat /etc/wireguard/private.key)
  Address = 10.0.0.9/24
  ListenPort = 51820
  [Peer]
  PublicKey = 2NqkRje1H7GAsDNBdjgHOOWzCIDz1A8AJ9RJTWCfQD4=
  Endpoint = 192.168.0.10:51820
  PersistentKeepalive = 25
  AllowedIPs = 10.0.0.1/32
  EOF
- chmod 600 /etc/wireguard/wg0.conf
- systemctl enable --now wg-quick@wg0
- |
  cat > /etc/netplan/00-installer-config.yaml << EOF
  network:
    version: 2
    ethernets:
      enp2s0:
        dhcp4: true
  EOF
- netplan apply
```

3. Create VM

```sh
sudo virt-install --name ubuntu2404-test-vm \
  --cpu host-passthrough,cache.mode=passthrough \
  --vcpus 4,maxvcpus=4,sockets=1,cores=2,threads=2 \
  --memory 8192 \
  --os-variant ubuntu24.04 \
  --graphics none \
  --video model.type=none \
  --serial pty \
  --console pty,target.type=virtio \
  --noautoconsole \
  --network bridge=virbr0 \
  --network bridge=br-enp112s0 \
  --boot uefi \
  --boot hd,cdrom,menu=on \
  --boot loader=/usr/share/edk2/ovmf/OVMF_CODE.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/edk2/ovmf/OVMF_VARS.fd \
  --disk /var/lib/libvirt/images/ubuntu2404-test-vm.qcow2,bus=virtio \
  --hostdev pci_0000_03_00_0 \
  --hostdev pci_0000_03_00_1 \
  --import \
  --cloud-init user-data=cloud-init.conf.yaml 
```

Clean up

```sh
sudo virsh destroy ubuntu2404-test-vm
sudo virsh undefine ubuntu2404-test-vm --remove-all-storage --nvram
```
