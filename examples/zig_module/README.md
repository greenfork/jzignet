# Example: Janet module in Zig

This example creates Janet script or executable using Zig module
located at <https://github.com/greenfork/jzignet-module-template>. This
module is supposed to be used as a template for your modules as well.

Requires Zig version of at least 0.10.0, zig executable must be in PATH.
You can download the latest Zig build from <https://ziglang.org/download/>.
You will also need Janet and jpm installed on your system
<https://github.com/janet-lang/janet/releases>.

## How to use

1. Install our dependency at
   <https://github.com/greenfork/jzignet-module-template>:
   ```shell
   $ jpm -l deps
   ```

2. Run the Janet source code
   ```shell
   $ jpm -l janet src/main.janet
   1
   6
   ```

3. Or from the shell
   ```janet
   $ jpm -l janet

   (use zig_module)
   (def st (init-struct))  #=> <zig-struct 0x55F68500AEC0>
   (get-counter st)        #=> 1
   (add st 5)              #=> nil
   (get-counter st)        #=> 6
   # Ctrl-D to quit
   ```

4. Or compile into static binary
   ```shell
   $ jpm -l build
   $ ./build/janet_exec
   1
   6
   ```
