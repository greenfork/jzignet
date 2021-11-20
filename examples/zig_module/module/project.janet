(declare-project
  :name "zig_module"
  :author "Dmitry Matveyev <dev@greenfork.me>")

(task "build" []
      (shell "zig" "build")
      (os/mkdir "build")
      (copy "zig-out/lib/libzig_module.a" "build/zig_module.a")
      (copy "zig-out/lib/libzig_module.so" "build/zig_module.so")
      (spit "build/zig_module.meta.janet"
            (string/format
             "# Metadata for static library %s\n\n%.20p"
             "zig_module.a"
             {:static-entry "janet_module_entry_zig_module"
              :cpp false
              :ldflags '(quote nil)
              :lflags '(quote nil)})))
