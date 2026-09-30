// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import '../rp2040.dart';

abstract interface class IGDBTarget {
  bool get executing;
  RP2040 get rp2040;

  void execute();
  void stop();
}
