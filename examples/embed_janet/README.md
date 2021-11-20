# Example: Embed Janet into Zig

If you don't have Zig installed, you can download it from official Zig
website <https://ziglang.org/download/>. You don't need Janet installed,
Janet is built into this wrapper.

How to run:
```shell
$ zig build run
# or
$ zig build
$ ./zig-out/bin/embed_janet
# or for release build
$ zig build -Drelease-safe
```

You can look at the source code, it is heavily commented.
