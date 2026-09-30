// Boot MicroPython from reset and run 3 simulated seconds; print speed and a
// state hash. The same loop as reference/bench.ts, for comparing with rp2040js.
//
//   dart run tool/bench.dart reference/micropython.uf2
import 'package:rp2040_dart/bootrom.dart';
import 'package:rp2040_dart/rp2040_dart.dart';
import 'package:rp2040_dart/src/clock/simulation_clock.dart';

import '../example/load_flash.dart';

void main(List<String> args) {
  final clock = SimulationClock();
  final mcu = RP2040(clock);
  mcu.logger = ConsoleLogger(LogLevel.Error);
  mcu.loadBootrom(bootromB1);
  loadUF2(args.isEmpty ? 'reference/micropython.uf2' : args.first, mcu);
  mcu.core.PC = 0x10000000;

  const cycleNanos = 1e9 / 125000000;
  const target = 3e9;
  var instructions = 0;
  final sw = Stopwatch()..start();
  while (clock.nanos < target) {
    if (mcu.core.waiting) {
      final n = clock.nanosToNextAlarm;
      clock.tick(n > 0 ? n : cycleNanos);
    } else {
      clock.tick(mcu.core.executeInstruction() * cycleNanos);
      instructions++;
    }
  }
  final secs = sw.elapsedMicroseconds / 1e6;
  var h = 7;
  for (final r in mcu.core.registers) {
    h = (h * 31 + r) % 4294967291;
  }
  for (final b in mcu.sram) {
    h = (h * 31 + b) % 4294967291;
  }
  print(
    'state ${h.toRadixString(16)} pc=${mcu.core.PC.toRadixString(16)} instructions=$instructions',
  );
  print(
    'x${(target / 1e9 / secs).toStringAsFixed(2)} real time, '
    '${(instructions / secs / 1e6).toStringAsFixed(1)} M instructions/s',
  );
}
