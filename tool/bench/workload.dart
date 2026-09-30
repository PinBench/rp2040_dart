// MicroPython doing real work, for comparing with rp2040js
// (reference/bench_py.ts runs the same thing): boot, wait for the REPL, type
// one line of pure computation over USB, and time it until the result.
import 'package:rp2040_dart/bootrom.dart';
import 'package:rp2040_dart/rp2040_dart.dart';
import 'package:rp2040_dart/src/clock/simulation_clock.dart';

const line = 'print(sum(i * i % 7 for i in range(30000)))\r';

void runWorkload(void Function(RP2040 mcu) loadImage) {
  final clock = SimulationClock();
  final mcu = RP2040(clock);
  mcu.logger = ConsoleLogger(LogLevel.Error);
  mcu.loadBootrom(bootromB1);
  loadImage(mcu);
  mcu.core.PC = 0x10000000;
  final cdc = USBCDC(mcu.usbCtrl);
  final out = StringBuffer();
  var fresh = false;
  cdc.onDeviceConnected = () {
    cdc.sendSerialByte(13);
    cdc.sendSerialByte(10);
  };
  cdc.onSerialData = (value) {
    out.write(String.fromCharCodes(value));
    fresh = true;
  };

  final core = mcu.core;
  const cycleNanos = 1e9 / 125000000;
  var instructions = 0;
  void runUntil(bool Function() done) {
    // The finish condition is checked only when new output has arrived, so the
    // loop times the emulator rather than string handling.
    for (;;) {
      if (fresh) {
        fresh = false;
        if (done()) return;
      }
      if (instructions > 2000000000) return;
      if (core.waiting) {
        final n = clock.nanosToNextAlarm;
        clock.tick(n > 0 ? n : cycleNanos);
      } else {
        clock.tick(core.executeInstruction() * cycleNanos);
        instructions++;
      }
    }
  }

  runUntil(() => out.toString().contains('>>> '));
  out.clear();
  for (final c in line.codeUnits) {
    cdc.sendSerialByte(c);
  }
  final i0 = instructions;
  final sw = Stopwatch()..start();
  final finished = RegExp(r'\r\n\d+\r\n>>> $');
  runUntil(
    () => finished.hasMatch(out.toString()) || instructions - i0 > 2000000000,
  );
  final secs = sw.elapsedMicroseconds / 1e6;
  var h = 7;
  for (final r in mcu.core.registers) {
    h = (h * 31 + r) % 4294967291;
  }
  for (final b in mcu.sram) {
    h = (h * 31 + b) % 4294967291;
  }
  final result = out.toString().trim().split('\r\n')[1];
  print(
    'result $result state ${h.toRadixString(16)} instructions=${instructions - i0}',
  );
  print(
    '${((instructions - i0) / secs / 1e6).toStringAsFixed(1)} M instructions/s',
  );
}
