// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:async';

import 'clock/simulation_clock.dart';
import 'gdb/gdb_target.dart';
import 'rp2040.dart';

class Simulator implements IGDBTarget {
  /// rp2040js's `setTimeout(..., 0)` handle: a zero-duration [Timer], which
  /// yields to the event loop between batches. (`Timer(Duration.zero, ...)` is
  /// what `Timer.run` does, but `Timer.run` returns no handle to cancel.)
  Timer? executeTimer;
  @override
  RP2040 rp2040;
  bool stopped = true;

  final SimulationClock clock;

  Simulator([SimulationClock? clock]) : this._(clock ?? SimulationClock());

  Simulator._(this.clock) : rp2040 = RP2040(clock) {
    rp2040.onBreak = (_) => stop();
  }

  @override
  void execute() {
    final rp2040 = this.rp2040;
    final clock = this.clock;
    // Read once: `core` is a `late` field (it needs `this`), so each read of
    // it pays a check, and this loop reads it for every instruction.
    final core = rp2040.core;

    executeTimer = null;
    stopped = false;
    const cycleNanos = 1e9 / 125000000; // 125 MHz
    // A double, as in rp2040js: a WFI/WFE skip advances it by a fractional cycle count.
    for (var i = 0.0; i < 1000000 && !stopped; i++) {
      if (core.waiting) {
        final nanosToNextAlarm = clock.nanosToNextAlarm;
        clock.tick(nanosToNextAlarm);
        i += nanosToNextAlarm / cycleNanos;
      } else {
        final cycles = core.executeInstruction();
        // `toDouble()` first: `int * double` is a generic `num` multiply, which
        // dart2wasm boxes (an allocation per instruction).
        clock.tick(cycles.toDouble() * cycleNanos);
      }
    }
    if (!stopped) {
      executeTimer = Timer(Duration.zero, execute);
    }
  }

  @override
  void stop() {
    stopped = true;
    if (executeTimer != null) {
      executeTimer!.cancel();
      executeTimer = null;
    }
  }

  @override
  bool get executing => !stopped;
}
