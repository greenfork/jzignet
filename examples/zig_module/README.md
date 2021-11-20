# Example: Janet module in Zig

This is a bit ugly but it works. Requires Zig version of at least 2021-11-20.
You can download the latest Zig build from <https://ziglang.org/download/>. You
will also need Janet installed on your system
<https://github.com/janet-lang/janet/releases>.

This example consists of two parts:
1. Janet module which is written in Zig - this is the Zig code that we will
   use in Janet.
2. Executable which is a Janet project - this is our Janet code which we
   can run interpreted or compile into a binary with jpm.

The build steps are as follows:

1. Go to `module/` directory, where the Zig module is
   ```shell
   $ cd module/
   ```

2. Build the Zig shared and static libraries
   ```shell
   $ zig build
   ```

3. Run the jpm task to copy the compiled libraries and create a
   metadata file, look at `project.janet` for details
   ```shell
   $ jpm run build-zig
   ```

4. Go to `executable/` directory, where the Janet project is
   ```shell
   $ cd ../executable/
   ```

5. Create a local jpm directory tree structure
   ```shell
   $ jpm -l deps
   ```

6. Copy the previously created files to the library directory
   ```shell
   $ cp ../module/build/* jpm_tree/lib/
   ```

7. Run the Janet source code
   ```shell
   $ jpm -l janet src/main.janet
   ```

8. Or from the shell
   ```janet
   $ jpm -l janet

   (use zig_module)
   (def st (init-struct))  #=> <zig-struct 0x55F68500AEC0>
   (get-counter st)        #=> 1
   (add st 5)              #=> nil
   (get-counter st)        #=> 6
   # Ctrl-D to quit
   ```

9. Or compile into static binary
   ```shell
   $ jpm -l clean
   $ jpm -l build
   $ ./build/janet_exec
   ```
