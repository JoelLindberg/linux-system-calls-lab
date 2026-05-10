# Lab 2 - Adding a syscall

1. Create a new VM for this experiment
2. Login to the new VM and clone the Linux source code:
    ```bash
    `git clone --depth 1 https://github.com/torvalds/linux.git`
    ```
3. Modify the source files to add a new syscall: `hello_world`
    * Add the syscall number in `include/uapi/asm-generic/unistd.h`
    * Add the syscall function in `kernel/sys.c`
    * Add the syscall prototype in `include/linux/syscalls.h`
4. Compile the kernel and install it?
5. 

References:
* Adding a new syscall: https://www.kernel.org/doc/html/latest/process/adding-syscalls.html
* Github source code: https://github.com/torvalds/linux
* Online source code ref: https://elixir.bootlin.com/linux/v7.0.5/source/include/linux/syscalls.h
