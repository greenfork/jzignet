(declare-project
  :name "zig_module")

(phony "build-release" []
  (os/execute ["zig" "build" "-Drelease-safe"] :p)
  (os/mkdir "build")

  # Copy static and shared libraries to `build` also renaming them.
  (copy "zig-out/lib/libzig_module.a" "build/zig_module.a")
  (copy "zig-out/lib/libzig_module.so" "build/zig_module.so"))

(phony "build-debug" []
  (os/execute ["zig" "build"] :p)
  (os/mkdir "build")

  # Copy static and shared libraries to `build` also renaming them.
  (copy "zig-out/lib/libzig_module.a" "build/zig_module.a")
  (copy "zig-out/lib/libzig_module.so" "build/zig_module.so"))

(phony "clean-target" []
  (rm "zig-out/lib/libzig_module.a")
  (rm "zig-out/lib/libzig_module.so"))

(post-deps
  (declare-native
    :name "zig_module"
    :source [])

  (add-dep "build" "build-release")
  (add-dep "clean" "clean-target"))
