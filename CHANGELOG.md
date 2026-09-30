# Changelog

## 0.1.0 (unreleased)

Initial port of rp2040js v1.4.0 (commit `a304c74`).

### Performance

Faster than rp2040js on every target, and 2.1-2.3x on WebAssembly (was
0.83x), with the emulated state after every benchmark identical to
rp2040js's. MicroPython workload, M instructions/s: wasm 42.7 -> ~80,
AOT 25.7 -> 52.3, dart2js 30.0 -> 40.3.

- **Decode table:** each 16-bit opcode is decoded once into a 64K table and
  `executeInstruction` switches on it, instead of testing up to 83 masks per
  instruction. The table is built from rp2040js's own if-chain, in its
  order; 32-bit instructions are decoded from both half-words when they run.
- **Instruction fetch** reads flash, the boot ROM and RAM directly, and the
  core's small accessors carry `prefer-inline` pragmas.
- **Bus:** RAM stores are tested before the peripheral lookup (no RAM
  address maps to a peripheral), and `findPeripheral` reads a dense array
  kept beside the `peripherals` map, which stays a writable `Map`.
- **Run loop:** `Simulator.execute` reads `rp2040.core` once and converts the
  cycle count before multiplying (an `int * double` is a boxing `num`
  multiply under dart2wasm).
- **Startup:** the 16 MB flash erase on reset uses doubling bulk copies
  instead of a per-byte fill (20-60 ms -> 2-8 ms).

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
