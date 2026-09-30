// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'peripheral.dart';

const int _PLATFORM = 0;
const int _ASIC = 1;

class RPTBMAN extends BasePeripheral implements Peripheral {
  RPTBMAN(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _PLATFORM:
        return _ASIC;
      default:
        return super.readUint32(offset);
    }
  }
}
