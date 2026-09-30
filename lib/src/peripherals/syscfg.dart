// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'peripheral.dart';

const int _PROC0_NMI_MASK = 0;
// ignore: unused_element
const int _PROC1_NMI_MASK = 4;

class RP2040SysCfg extends BasePeripheral implements Peripheral {
  RP2040SysCfg(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _PROC0_NMI_MASK:
        return rp2040.core.interruptNMIMask;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _PROC0_NMI_MASK:
        rp2040.core.interruptNMIMask = value;
        break;

      default:
        super.writeUint32(offset, value);
    }
  }
}
