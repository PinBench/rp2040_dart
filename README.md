# rp2040_dart

A pure Dart port of [rp2040js](https://github.com/wokwi/rp2040js), Wokwi's
Raspberry Pi RP2040 (Pico) emulator: the Cortex-M0+ core, SIO, PIO, DMA,
USB, UART, I²C, SPI, PWM, ADC, timers and the rest of the chip, with no
native dependency. It runs on the Dart VM, compiled to JavaScript and to
WebAssembly, so the same emulator works in Flutter apps on desktop, mobile
and the web.

Its sibling [`avr8_dart`](https://pub.dev/packages/avr8_dart) does the same
for AVR (Arduino Uno).

## Status

A line-by-line port of rp2040js **v1.4.0** (commit `a304c74`); the rules it
follows, above all for 32-bit arithmetic, are in [`PORTING.md`](PORTING.md).

- **Tests:** all 315 rp2040js spec cases, same names, pass on the Dart VM,
  compiled to JavaScript and compiled to WebAssembly.
- **Identical to rp2040js:** booting MicroPython v1.20.0 for 3 simulated
  seconds ends in the same CPU and RAM state (hash `9893d66b`, 3,990,398
  instructions) on rp2040js and on every Dart target, and the MicroPython
  REPL runs over emulated USB (`example/micropython_run.dart`).
- **Speed** on that run (Apple M-series, `dart run tool/bench.dart`):

  | | M instructions/s | vs rp2040js |
  | --- | --- | --- |
  | rp2040js (Node) | 20.0 | 1.00x |
  | Dart AOT | 29.7 | 1.49x |
  | dart2js | 25.3 | 1.27x |
  | Dart JIT | 20.2 | 1.01x |
  | dart2wasm | 16.6 | 0.83x |

## Usage

```dart
import 'package:rp2040_dart/bootrom.dart';
import 'package:rp2040_dart/rp2040_dart.dart';

void main() {
  final simulator = Simulator();
  final mcu = simulator.rp2040..loadBootrom(bootromB1);
  // Copy a program into mcu.flash (example/load_flash.dart reads UF2 and
  // Intel HEX), then start it from flash:
  mcu.core.PC = 0x10000000;
  mcu.uart[0].onByte = (byte) => print(String.fromCharCode(byte));
  simulator.execute();
}
```

`example/` runs a Pico SDK binary (`emulator_run.dart`, with a GDB server on
port 3333) and the MicroPython REPL (`micropython_run.dart`).

## Licence

MIT, like rp2040js. The boot ROM image in `lib/src/bootrom.dart` is
Raspberry Pi's, under BSD-3-Clause.
