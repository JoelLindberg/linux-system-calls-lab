Call system call write to print a string to stdout

1. Compile the program: `gcc -o hello.out main.c`
2. Run the program: `strace ./hello.out`

Pay attention to the output of strace, you should be able to see something like:
```bash
write(1, "hello world\n", 12hello world
)           = 12
```
The above is your program calling the system call write.

Check the manual for write: `man 2 write` \
*'2'* in `man 2 write` is the section of the manual, 2 means system calls.

* The first argument is the file descriptor, 1 is stdout.
* The second argument is the string to print.
* The third argument is the length of the string to print.
* The return value is the number of bytes written.
