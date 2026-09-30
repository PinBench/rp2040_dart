// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'simulation_clock.dart';

class MockClock extends SimulationClock {
  MockClock([super.frequency]);

  void advance(double deltaMicros) {
    tick(nanos + deltaMicros * 1000);
  }
}
