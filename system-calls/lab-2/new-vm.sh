#!/bin/bash
# We copy our images and public ssh key to `/var/lib/libvirt/images/`
# because qemu is not allowed to access them in our /home/$USER folder
# due to QEMU+AppArmor isolation (which is a good thing).

INSTALL_DIR="/var/lib/libvirt/images"

if [ ! -w "$INSTALL_DIR" ]; then
    echo "Elevated privileges required to write to $INSTALL_DIR"
    SUDO="sudo -E"
fi

TEMPLATE="cloud-config.yml.tmpl"
URL="https://repo.almalinux.org/almalinux/10/cloud/x86_64/images/AlmaLinux-10-GenericCloud-latest.x86_64.qcow2"
IMAGE="$INSTALL_DIR/AlmaLinux-10-GenericCloud-latest.x86_64.qcow2"
DOWNLOADS="$HOME/Downloads/$(basename "$IMAGE")"


# Check if public key exists in libvirt images, copy from ~/.ssh if needed, or generate
if [ ! -f "$INSTALL_DIR/system-calls-lab.pub" ]; then
    if [ -f "$HOME/.ssh/system-calls-lab.pub" ]; then
        echo "Copying SSH key from ~/.ssh to libvirt images..."
        $SUDO cp "$HOME/.ssh/system-calls-lab.pub" "$INSTALL_DIR/system-calls-lab.pub"
    else
        echo "SSH key not found in ~/.ssh/system-calls-lab.pub"
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
envsubst < "$TEMPLATE" > "$INSTALL_DIR/cloud-config_${NODE}.yml"

$SUDO virt-install \
    --connect qemu:///system \
    --name "$NODE" \
    --memory 2048 \
    --vcpus 2 \
    --os-variant almalinux10 \
    --cpu host-passthrough \
    --disk size=10,backing_store="$IMAGE",bus=virtio \
    --cloud-init user-data="$INSTALL_DIR/cloud-config_${NODE}.yml" \
    --network bridge=virbr0 \
    --graphics spice \
    --console pty,target_type=serial \
    --import \
    --noautoconsole

echo "------------------------------------------------"
echo "Lab VM is now up! Check status with 'virsh list --all'"
