# Jzignet

[Zig](https://ziglang.org/) is a general-purpose programming language and
toolchain for maintaining robust, optimal, and reusable software.

[Janet](https://janet-lang.org/) is a functional and imperative programming
language and bytecode interpreter. It is a lisp-like language, but lists are
replaced by other data structures (arrays, tables (hash table), struct
(immutable hash table), tuples). The language also supports bridging to native
code written in C, meta-programming with macros, and bytecode assembly.

[Jzignet](https://git.sr.ht/~greenfork/jzignet) - Zig library to connect Janet
and Zig together.

You can:
* Embed Janet programs into Zig
* Write Janet modules in Zig
* Write bindings in Zig for a C library to be used as a Janet module

Why use these bindings, besides obvious reasons such as connecting together two
wonderful languages:
* You don't need to care about conversion between Zig and C. But you have full
  access to C internals if you need to.
* Plenty of tests which are great examples and guarantee minimal regressions
  when updating.
* Idiomatic Zig code - everything is typed, names are properly cased,
  operations on types use methods instead of prefixed global functions.

## How to use

If you want to just start using it, jump to the examples. Copy them or look
at the source code, it is heavily commented. Every example also has a readme
file.

* [Embed Janet into Zig](examples/embed_janet)
* [Write Janet module in Zig](examples/zig_module)

Currently you can include jzignet as a git submodule. Janet is bundled as
a single C source amalgamation file and is compiled directly into this
library.

1. Include git submodule into your library, assuming further that `libpath` is
   the directory where this library is installed
   ```shell
   git submodule add https://git.sr.ht/~greenfork/jzignet libpath
   ```

2. Include bundled Janet in `build.zig`
   ```zig
   const janet = b.addStaticLibrary("janet", null);
   janet.addCSourceFile("libpath/c/janet.c", &[_][]const u8{"-std=c99"});
   janet.addIncludeDir("libpath/c");
   janet.linkLibC();
   ```

3. Link the bundled Janet to your program in `build.zig`. Here the example is
   for an executable, for library it is similar, see the `build.zig` files
   in the examples
   ```zig
   exe.linkLibC();
   exe.linkLibrary(janet);
   exe.addPackagePath("jzignet", "libpath/src/janet.zig");
   exe.addIncludeDir("libpath/c");
   ```

## Differences with C API

### Naming
* `janet_` prefix is mostly not present.
* Every type is a Zig struct and corresponding functions are called as
  methods, for example, `janet_table_get(table, key)` becomes `table.get(key)`.
* Some Janet functions have inconsistent naming, for example, `janet_wrap_number`
  but `janet_getnumber`. **All** bindings have idiomatic Zig naming, in this
  example it would be `wrapNumber` and `getNumber`, it affects both function
  names and struct member names.
* Functions like `janet_table` are available as `Table.init`, please consult
  the source code for that.

### Semantics
* Function return types return error sets as well as optional values where it
  makes sense to do so, for example, `get` returns `?Janet` and `unwrapNumber`
  returns `!i32`.
* All types are wrapped in a struct. Most of the types support this natively
  since they are structs in C too, others (Tuple, Struct, String, Keyword,
  Symbol) cannot be represented as structs directly and they are wrappers
  with a `ptr` or `slice` field containing the original value.
* When you need to supply a pointer to the array and a length in the C version,
  in Zig version you need to supply just a slice since it has both the pointer
  and the length, so it's one parameter instead of two. For example,
  ```c
  int janet_dobytes(JanetTable *env, const uint8_t *bytes, int32_t len, const char *sourcePath, Janet *out);
  ```
  
  becomes
  ```zig
  pub fn doBytes(env: *Table, bytes: []const u8, source_path: [:0]const u8, out: ?*Janet) !void
  ```
* Abstracts are fully typed, no *void pointers to @ptrCast. Take a look at
  tests for examples with abstracts, they are generally reworked to make
  them easier to use.

## Completeness

Bindings are not complete 100% but all the generally useful things are there.
If you need any specific part of the API, feel free to contribute or just
ask (and you shall receive).

## Q'n'A

Q: What's with the name?

A: "janet".replace("a", "zig")

Q: I hate that name.

A: Yes, I know.

## License

MIT, see LICENSE file.
