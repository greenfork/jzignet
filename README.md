# Jzignet - Janet wrapper for Zig

[Zig](https://ziglang.org/) is a general-purpose programming language and
toolchain for maintaining robust, optimal, and reusable software.

[Janet](https://janet-lang.org/) is a functional and imperative programming
language.

Jzignet - Zig library which allows to embed Janet programs into Zig programs.

You can:
* Embed Janet programs into Zig
* Write Janet modules in Zig (in progress)
* Write bindings in Zig for a C library to be used as a Janet module (in progress)

Why use these bindings:
* You don't need to care about conversion between Zig and C. But you have full
  access to C internals if you need to.
* Plenty of tests which are great examples.
* Idiomatic Zig code.

# How to use

# Differences with C API
## Naming
* `janet_` prefix is mostly not present.
* Every type is a Zig struct and corresponding functions are called as
  methods, for example, `janet_table_get(table, key)` becomes `table.get(key)`.
* Some Janet functions have inconsistent naming, for example, `janet_wrap_number`
  but `janet_getnumber`. **All** bindings have idiomatic Zig naming, in this
  example it would be `wrapNumber` and `getNumber`.

## Semantics
* Return types return error sets as well as optional values where it makes
  sense to do so.
* All types are wrapped in a struct. Most of the types support this natively
  since they are structs in C too, others (Tuple, Struct, String, Keyword,
  Symbol) cannot be represented as structs directly and they are wrappers
  with a `ptr` or `slice` field containing the original type.

# Q'n'A

Q: What's with the name?  
A: "Janet".replace("a", "zig")

Q: I hate that name.  
A: Yes, I know.

# License

MIT, see LICENSE file.
