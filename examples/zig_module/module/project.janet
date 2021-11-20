(declare-project
  :name "zig_module"
  :author "Dmitry Matveyev <dev@greenfork.me>")

(task "build-zig" []
      # Create directory where our final Janet module will be.
      (os/mkdir "build")

      # Copy static and shared libraries to `build` also renaming them.
      (copy "zig-out/lib/libzig_module.a" "build/zig_module.a")
      (copy "zig-out/lib/libzig_module.so" "build/zig_module.so")

      # Create a metadata file used by Janet to compile the static library
      # into the Janet native executable.
      (spit "build/zig_module.meta.janet"
            (string/format
             "# Metadata for static library %s\n\n%.20p"
             "zig_module.a"
             {:static-entry "janet_module_entry_zig_module"
              :cpp false
              :ldflags '(quote nil)
              :lflags '(quote nil)})))
