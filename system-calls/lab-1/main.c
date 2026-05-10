#include <unistd.h>

int main(void)
{
    // write is a system call that writes data to a file descriptor
    // Write "z" to stdout
    // 1 is the file descriptor for stdout, "hello world\n" is the string to write, 12 is the number of bytes to write
    write(1, "hello world\n", 12);
    return (0);
}
