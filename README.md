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
* Plenty of tests which are great examples and guarantee minimal regressions
  when updating.
* Idiomatic Zig code - everything is typed, names are properly cased,
  operations on types use methods instead of prefixed global functions.

# How to use

TODO

# Differences with C API

## Naming
* `janet_` prefix is mostly not present.
* Every type is a Zig struct and corresponding functions are called as
  methods, for example, `janet_table_get(table, key)` becomes `table.get(key)`.
* Some Janet functions have inconsistent naming, for example, `janet_wrap_number`
  but `janet_getnumber`. **All** bindings have idiomatic Zig naming, in this
  example it would be `wrapNumber` and `getNumber`.
* Functions like `janet_table` are available as `Table.init`

## Semantics
* Return types return error sets as well as optional values where it makes
  sense to do so.
* All types are wrapped in a struct. Most of the types support this natively
  since they are structs in C too, others (Tuple, Struct, String, Keyword,
  Symbol) cannot be represented as structs directly and they are wrappers
  with a `ptr` or `slice` field containing the original type.
* When you need to supply a pointer to the array and a length in the C version,
  in Zig version you need to supply a slice since it has both the pointer and
  the length.
* Abstracts are fully typed, no *void pointers to @ptrCast.

# Completeness

Bindings are not complete 100% but all the generally useful things are here.
If you need any specific part of API, feel free to contribute or just
ask (and you shall receive).

# Q'n'A

Q: What's with the name?  
A: "janet".replace("a", "zig")

Q: I hate that name.  
A: Yes, I know.

# License

MIT, see LICENSE file.
