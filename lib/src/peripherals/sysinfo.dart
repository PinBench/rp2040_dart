// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'peripheral.dart';

const int _CHIP_ID = 0;
const int _PLATFORM = 0x4;
const int _GITREF_RP2040 = 0x40;

class RP2040SysInfo extends BasePeripheral implements Peripheral {
  RP2040SysInfo(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    // All the values here were verified against the silicon
    switch (offset) {
      case _CHIP_ID:
        return 0x10002927;

      case _PLATFORM:
        return 0x00000002;

      case _GITREF_RP2040:
        return 0xe0c912e8;
    }
    return super.readUint32(offset);
  }
}
