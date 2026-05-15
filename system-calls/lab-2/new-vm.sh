#!/bin/bash
# We copy our images and public ssh key to `/var/lib/libvirt/images/`
# because qemu is not allowed to access them in our /home/$USER folder
# due to QEMU+AppArmor isolation (which is a good thing).

INSTALL_DIR="/var/lib/libvirt/images"

if [ ! -w "$INSTALL_DIR" ]; then
    echo "Elevated privileges required to write to $INSTALL_DIR"
    SUDO="sudo -E"
else
    SUDO=""
fi

TEMPLATE="cloud-config.yml.tmpl"
URL="https://repo.almalinux.org/almalinux/10/cloud/x86_64/images/AlmaLinux-10-GenericCloud-latest.x86_64.qcow2"
IMAGE="$INSTALL_DIR/AlmaLinux-10-GenericCloud-latest.x86_64.qcow2"
DOWNLOADS="$HOME/Downloads/$(basename "$IMAGE")"
SSHKEY="system-calls-lab"

# Check if public key exists in libvirt images, copy from ~/.ssh if needed, or generate
if [ ! -f "$INSTALL_DIR/$SSHKEY.pub" ]; then
    if [ -f "$HOME/.ssh/$SSHKEY.pub" ]; then
        echo "Copying SSH key from ~/.ssh to libvirt images..."
        $SUDO cp "$HOME/.ssh/$SSHKEY.pub" "$INSTALL_DIR/$SSHKEY.pub"
    else
        echo "SSH key not found in ~/.ssh/$SSHKEY.pub"
    fi
fi

export SCALL_LAB_SSH_KEY=$(cat $INSTALL_DIR/system-calls-lab.pub)


# Check if image exists, copy from Downloads if needed, or prompt to download
if [ ! -f "$IMAGE" ]; then
    if [ -f "$DOWNLOADS" ]; then
        echo "Copying image from Downloads to libvirt images..."
        cp "$DOWNLOADS" "$IMAGE"
    else
        echo "Image not found in Downloads folder."
        read -p "Download from repo.almalinux.org? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            wget -O "$IMAGE" "$URL"
        else
            echo "Error: Image file required to proceed."
            exit 1
        fi
    fi
fi


# Launch your VM
echo "------------------------------------------------"
export NODE="system-calls-lab-host"
export NODE_NAME="$NODE"
envsubst < "$TEMPLATE" | $SUDO tee "$INSTALL_DIR/cloud-config_${NODE}.yml" > /dev/null

$SUDO virt-install \
    --connect qemu:///system \
    --name "$NODE" \
    --memory 8192 \
    --vcpus 4 \
    --os-variant almalinux10 \
    --cpu host-passthrough \
    --disk size=20,backing_store="$IMAGE",bus=virtio \
    --cloud-init user-data="$INSTALL_DIR/cloud-config_${NODE}.yml" \
    --network bridge=virbr0 \
    --graphics spice \
    --console pty,target_type=serial \
    --import \
    --noautoconsole

echo "------------------------------------------------"
echo "Lab VM is now up! Check status with 'virsh list --all'"

echo "Sleeping for 30 seconds to allow the VM to boot and get an IP address for ssh.cfg"
sleep 30  # Wait for VM to boot

# Prep ssh.cfg
SCALL_IP="$(virsh guestinfo system-calls-lab-host --interface | grep 'if.1.addr.0.addr' | awk '{ print $3 }')"

# Fail fast if any IP was not found
if [ -z "$SCALL_IP" ]; then
    echo "Error: could not resolve one or more VM IPs from 'virsh guestinfo'." >&2
    exit 1
fi

# Generate ssh config
cat <<EOF > ssh.cfg
Host scall
  HostName ${SCALL_IP}
  User scall
  IdentityFile ~/.ssh/system-calls-lab
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
EOF

echo "Connect using 'ssh scall -F ssh.cfg'"
