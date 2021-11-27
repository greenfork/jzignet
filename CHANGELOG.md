# Changelog

## Development

All changes are most probably breaking.

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
  * All the named wrap functions are moved into `Janet` with a signature
    `wrap(comptime T: type, value: T) Janet` so you can use it like
    `Janet.wrap(i32, 3)`.
  * `wrapNumberSafe` moved into `Janet.numberSafe`.
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
