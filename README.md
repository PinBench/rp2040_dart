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
- **Speed**, in million emulated instructions per second (Apple M-series,
  medians of three runs). *Workload*: MicroPython running one line of pure
  computation typed over emulated USB (`tool/bench_py.dart`, and
  `reference/bench_py.ts` for rp2040js). *Boot*: 3 simulated seconds from
  reset (`tool/bench.dart`). Both end in the same state as rp2040js on every
  target.

  | | Workload | vs rp2040js | Boot | vs rp2040js |
  | --- | --- | --- | --- | --- |
  | rp2040js (Node) | 34.1 | 1.00x | 22.1 | 1.00x |
  | **dart2wasm** | **~80** | **2.3x** | **~46** | **2.1x** |
  | Dart AOT | 52.3 | 1.53x | 53.2 | 2.41x |
  | dart2js | 40.3 | 1.18x | 30.5 | 1.38x |

  Startup (`RP2040()` plus `loadBootrom`) takes 2 ms native, 3 ms dart2js
  and 8 ms Wasm.

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
