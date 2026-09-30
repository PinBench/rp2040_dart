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

A line-by-line port of rp2040js **v1.4.0** (commit `a304c74`). The rules the
port follows, in particular for 32-bit arithmetic, are in
[`PORTING.md`](PORTING.md).

## Usage

```dart
import 'package:rp2040_dart/rp2040_dart.dart';
import 'package:rp2040_dart/bootrom.dart';

final mcu = RP2040()..loadBootrom(bootromB1);
// Copy a program into mcu.flash (see example/load_flash.dart for UF2 and
// Intel HEX), then:
mcu.core.PC = 0x10000000;
mcu.uart[0].onByte = (byte) => print(String.fromCharCode(byte));
final sim = Simulator()..rp2040.loadBootrom(bootromB1);
```

See `example/` for running a Pico SDK binary and the MicroPython REPL.

## Licence

MIT, like rp2040js. The boot ROM image in `lib/src/bootrom.dart` is
Raspberry Pi's, under BSD-3-Clause.
