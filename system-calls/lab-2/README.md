# Lab 2 - Adding a syscall

References:
* Adding a new syscall: https://www.kernel.org/doc/html/latest/process/adding-syscalls.html
* Github source code: https://github.com/torvalds/linux
* Online source code ref: https://elixir.bootlin.com/linux/v7.0.5/source/include/linux/syscalls.h

Lab conducted on:
* Host OS: Ubuntu 24.04 LTS running on a MBP 2014
* Guest OS: `AlmaLinux 10.1` running under KVM/QEMU using `virsh` to manage the VM
  * CPU: 4 vCPUs
  * RAM: 8GB (compilation requires a lot of RAM)
  * Disk: 20GB


## Steps

1. Create a new VM for this experiment: `sudo ./new-vm.sh`
    If the packages failed to install you need to make sure these are installed:
    ```bash
    sudo dnf install -y gcc make flex bison elfutils-libelf-devel openssl-devel bc perl git vim strace
    ```
    *Troubleshooting cloud-init (in the guest VM):* `cat /var/log/cloud-init-output.log`
2. Login to the new VM and clone the Linux source code:
    ```bash
    git clone --depth 1 --branch v6.12 https://github.com/torvalds/linux.git
    ```
3. Modify the source files to add a new syscall: `hello_world` \
    Summary of substeps:
      * Create the syscall directory: `mkdir hello_world`
      * Create the syscall module logic `hello_world/hello_world.c`
      * Create a Makefile for the syscall module `hello_world/Makefile`
      * Make sure our hello_world module is compiled `kernel/Kbuild`
      * Assign a number to the syscall `arch/x86/entry/syscalls/syscall_64.tbl`
      * Declare the syscall prototype `include/linux/syscalls.h`

    Detailed substeps: \
    **Create the syscall module logic**
    *KERN_INFO is a macro that tells the kernel to print the message to the kernel log.*
    `hello_world/hello_world.c`:
    ```c
    #include <linux/kernel.h>
    #include <linux/syscalls.h>
    
    SYSCALL_DEFINE0(hello_world) {
        printk(KERN_INFO "hello from hello_world\n");
        return 0;
    }
    ```
    
    **Create a Makefile for the syscall module**
    `hello_world/Makefile`:
    ```makefile
    obj-y := hello_world.o
    ```
    
    **Make sure our hello_world module is compiled**
    vim `Kbuild` (root folder):
    ```makefile
    obj-y += hello_world/
    ```
    
    **Assign a number to the syscall**
    Which file you assign the number in depends on which architecture you are targeting. For x86_64, you will need to assign a number in `arch/x86/entry/syscalls/syscall_64.tbl`. x86_64 is apparently considered legacy architecture and maintains its own historical table to ensure backwards compatibility. It ignores the generic list. For ARM64 for example, it's a different story which uses the generic list.
    vim `arch/x86/entry/syscalls/syscall_64.tbl` (append to the next available number at the bottom):
    ```
    463    common  hello_world     sys_hello_world
    ```
    
    **Declare the syscall prototype**
    *I decided to add it in below sys_mseal() to follow the same order which I added the syscall number in the previous step.*
    vim `include/linux/syscalls.h`:
    ```c
    asmlinkage long sys_hello_world(void);
    ```

4. Compile the kernel
    ```bash
    # Configure the kernel by copying the current config file and then running make olddefconfig
    sudo cp /boot/config-$(uname -r) .config
    sudo make olddefconfig       # ensures a clean baseline configuration (olddefconfig instead of oldconfig as the latter is interactive while the former is not)
    sudo make localmodconfig     # strips out any modules not currently loaded. 'make' below will build essentially everything otherwise which takes a long time.

    # We need to enable Xen modules explicitly as they have been excluded by localmodconfig
    # Enable base Xen guest support (built-in)
    sudo ./scripts/config --enable XEN
    # Enable the specific block and network drivers (as modules)
    sudo ./scripts/config --module XEN_NETDEV_FRONTEND
    sudo ./scripts/config --module XEN_BLKDEV_FRONTEND

    sudo make olddefconfig  # read the new configuration
    
    # Compile the kernel and its modules
    # Use -j$(nproc) to speed up the process (nproc is the number of processors)
    sudo make -j$(nproc)
    ```
5. Install the kernel and modules
    ```bash
    sudo make modules_install
    sudo make install
    ```
6. Change the default kernel:
    ```bash
    sudo grubby --set-default /boot/vmlinuz-6.12.0-dirty  # you obviously need to change the kernel version to the one you just built
    sudo grubby --default-kernel  # verify the default kernel
    ```
7. Reboot the system
    ```bash
    sudo reboot
    ```
8. Verify the kernel version
    ```bash
    uname -r
    cat /proc/sys/kernel/version
    ```
9. Verify the syscall is available
    ```bash
    grep hello_world /proc/kallsyms
    ```
10. Create a C program to call the syscall
    ```c
    #include <stdio.h>
    #include <unistd.h>
    #include <sys/syscall.h>
    
    int main() {
        long ret = syscall(463);
        printf("Syscall returned %ld\n", ret);
        return 0;
    }
    ```

    ```bash
    gcc hello_world.c -o hello_world
    ./hello_world
    ```
11. After running it you can confirm it works by checking the kernel logs
    ```bash
    sudo dmesg | tail
    ```
    You should see:
    ```
    [  101.606452] hello from hello_world
    ```
12. You can also see it being called using strace:
    ```bash
    strace ./hello_world
    ```
    You should see:
    ```
    syscall_0x1cf(0x7fffc9d27e48, 0x7fffc9d27e58, 0x403df0, 0, 0x7fe78b3e7200, 0x7fffc9d27e40) = 0
    ```
    The number `0x1cf` is the hexadecimal representation of the syscall number `463`.



## Libvirt

Manage VMs:

Get VMs:
1. `virsh list --all`

VM info:
1. `virsh guestinfo <name>`

Start / Stop VM:
1. `virsh start system-calls-lab-host`
2. `virsh shutdown system-calls-lab-host`

Remove a VM:
1. `virsh destroy <name>`
2. `virsh undefine <name> --remove-all-storage`
