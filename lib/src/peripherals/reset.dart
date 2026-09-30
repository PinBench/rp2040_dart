// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'peripheral.dart';

const int _RESET = 0x0; //Reset control.
const int _WDSEL = 0x4; //Watchdog select.
const int _RESET_DONE = 0x8; //Reset Done

class RPReset extends BasePeripheral implements Peripheral {
  int _reset = 0;
  int _wdsel = 0;
  final int _reset_done = 0x1ffffff;

  RPReset(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _RESET:
        return _reset;
      case _WDSEL:
        return _wdsel;
      case _RESET_DONE:
        return _reset_done;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _RESET:
        _reset = value & 0x1ffffff;
        break;
      case _WDSEL:
        _wdsel = value & 0x1ffffff;
        break;
      default:
        super.writeUint32(offset, value);
        break;
    }
  }
}
