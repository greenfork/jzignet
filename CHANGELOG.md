# Changelog

## Development

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
    these structures, for example `wrapTable` is moved into `Table.wrap()`
  * All the named wrap functions are moved into `Janet` with a signature
    `wrap(comptime T: type, value: T)` so you can use it like `Janet.wrap(i32, 3)`
  * `wrapNumberSafe` moved into `Janet.numberSafe`
* `string` function and corresponding for keyword and symbol are moved into
  their data structures into functions `init`
* `stringv` function and corresponding for keyword and symbol are moved into
  Janet into functions `string`, `keyword` and `symbol`
* `symbolGen` function is moved into `Symbol.gen`
* `abstract` function is moved into `Abstract.init` and `Abstract.initVoid`


* WIP Turn `Signal` return value into an error union
* WIP Turn more Fiber and Function functions into methods
* WIP Write more tests
