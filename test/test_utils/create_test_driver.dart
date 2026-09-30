// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/rp2040.dart';

import 'test_driver.dart';
import 'test_driver_rp2040.dart';

/// rp2040js can also drive real hardware over GDB (`TEST_GDB_SERVER`); the
/// Dart port only has the in-process driver.
ICortexTestDriver createTestDriver() => RP2040TestDriver(RP2040());
