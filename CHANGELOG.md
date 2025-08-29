# Changelog

## 0.7.6

* Zig was upgraded to 0.14.1

## 0.7.5

* Janet was upgraded to 1.37.1

## 0.7.4

* Zig was upgraded to 0.13.0

## 0.7.0

* Janet was upgraded to 1.25.1
* Zig was upgraded to 0.10.0

## 0.6.0

* Janet was upgraded to 1.23.0

## 0.5.0

* Janet was upgraded to 1.20.0

## 0.4.0

* Zig was upgraded to 0.9.0

## 0.3.0

All changes are most probably breaking.

* Janet was upgraded to 1.19.0.
* Major overhaul of C API.
* Module example is fully automated and native to jpm.

### C API

* Functions were moved into structs to be "methods":
  * `continue` into Fiber
  * `continueSignal` into Fiber
  * `step` into Fiber
  * `stackstrace` into Fiber
  * `pcall` into Function
  * `call` into Function
  * `tryInit` into TryState
  * `try` into TryState
  * `restore` into TryState
* `wrap` function overhaul:
  * All the functions which are applicable to data structures are moved into
    these structures, for example `wrapTable` is moved into `Table.wrap()`.
  * All the named wrap functions are now with a signature
    `wrap(comptime T: type, value: T) Janet` so you can use it like
    `wrap(i32, 3)`.
  * `wrapNumberSafe` is renamed to `numberSafe`.
* `unwrap` function overhaul:
  * All the functions except for abstract have changed their signature to
    `unwrap(janet: Janet, comptime T: type) !T` so you can use it like
    `try Janet.unwrap(i32)`.
* `string` function and corresponding for keyword and symbol are moved into
  their data structures into functions `init`.
* `stringv` function and corresponding for keyword and symbol are moved into
  Janet into functions `string`, `keyword` and `symbol`.
* `symbolGen` function is moved into `Symbol.gen`.
* `abstract` function is moved into `Abstract.init` and `Abstract.initVoid`.
* Introduce new `Environment` struct which is same as `Table` but only allows
  operations specific to environment manipulation.
* More data structures now have `init` or `initN` functions where `initN`
  initializes with supplied data for collection data structures.
* `Signal` return value is transformed into `Signal.Error!void` where
  `Signal.Error` is anything but `ok` signal.
* Functions such as `pcall` only take `[]const Janet` instead of both pointer
  and argument length.
* `doString` and `doBytes` functions always return `Janet` value instead of
  accepting a pointer `*Janet` as an argument.
* `printf` -> `print`, `eprintf` -> `eprint`.
* `registerAbstractType` is removed in favor of just `register`.
* Marshal/unmarshal type-specific functions live inside `MarshalContext`.
* `getType` and `optType` functions are reworked to receive type as the
  very first argument.
* "View" functions are moved inside `Janet` struct and now return a corresponding
  view data structure instead of getting the view from parameters by reference.
* `getAbstractType` is moved inside `Janet`.
* `in`, `get`, `next`, `getIndex` functions have their return type changed
  `Janet`->`?Janet`.
* `JanetType` is now `Janet.Type`.
* `fixarity` renamed to `fixArity`.
