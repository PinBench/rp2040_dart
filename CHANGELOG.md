# Changelog

## 0.1.0 (unreleased)

Initial port of rp2040js v1.4.0 (commit `a304c74`).

### Where it differs from rp2040js

Kept on purpose, so the two behave the same (each is commented in the code):
the watchdog's default handler reschedules itself with no delay once the
count reaches 0 and stalls the clock; the ADC's `activeChannel` setter masks
with the shift constant; `RPPWM`'s EN register always reads 0.

Changed, because Dart can't express the JavaScript behaviour or it was a bug
only visible there:

- **SIO signed divide by zero** compares the dividend as signed, so a
  negative dividend gives the hardware's quotient (1) for firmware as well;
  rp2040js got it right only for its own test, which passes a negative
  JavaScript number.
- **`RPUART.baudRate`** is 0 while the divider is unset (rp2040js: `Infinity`).
- **`Timer32`** with a zero `top` in zig-zag mode counts 0 (rp2040js: `NaN`,
  read back as 0).
- `USBDevice`, `USBTransferResult`, `ISetupPacketParams` are Dart classes;
  `extractEndpointNumbers` returns a record `({int in_, int out})` because
  `in` is reserved.
- The GDB TCP server is its own library (`gdb_tcp_server.dart`, `dart:io`) and
  gains `listening` and `close()`; the examples parse their own arguments and
  read UF2 without the `uf2` npm package.
