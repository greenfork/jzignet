# Module of a Zig module example

The build steps are as follows:
1. Run `zig build`. See `build.zig` file, it generates a static and a shared
   library from the Zig files.
2. Copy these library files to `build/`.
3. Create a meta file necessary for Janet's natively built libraries.
