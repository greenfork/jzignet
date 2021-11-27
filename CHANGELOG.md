# Changelog

## Development

* Functions were moved into structs to be "methods":
  * continue into Fiber
  * continueSignal into Fiber
  * step into Fiber
  * stackstrace into Fiber
  * pcall into Function
  * call into Function
  * tryInit into TryState
  * try into TryState
  * restore into TryState

* WIP Turn `Signal` return value into an error union
* WIP Turn more Fiber and Function functions into methods
* WIP Write more tests
