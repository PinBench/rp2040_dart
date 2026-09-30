// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'peripheral.dart';

/// Bus priority acknowledge
const int _BUS_PRIORITY_ACK = 0x004;

/// Bus fabric performance counter 0
const int _PERFCTR0 = 0x008;

/// Bus fabric performance event select for PERFCTR0
const int _PERFSEL0 = 0x00c;

/// Bus fabric performance counter 1
const int _PERFCTR1 = 0x010;

/// Bus fabric performance event select for PERFCTR1
const int _PERFSEL1 = 0x014;

/// Bus fabric performance counter 2
const int _PERFCTR2 = 0x018;

/// Bus fabric performance event select for PERFCTR2
const int _PERFSEL2 = 0x01c;

/// Bus fabric performance counter 3
const int _PERFCTR3 = 0x020;

/// Bus fabric performance event select for PERFCTR3
const int _PERFSEL3 = 0x024;

class RPBUSCTRL extends BasePeripheral implements Peripheral {
  int voltageSelect = 0;
  final List<int> perfCtr = [0, 0, 0, 0];
  final List<int> perfSel = [0x1f, 0x1f, 0x1f, 0x1f];

  RPBUSCTRL(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _BUS_PRIORITY_ACK:
        return 1;
      case _PERFCTR0:
        return perfCtr[0];
      case _PERFSEL0:
        return perfSel[0];
      case _PERFCTR1:
        return perfCtr[1];
      case _PERFSEL1:
        return perfSel[1];
      case _PERFCTR2:
        return perfCtr[2];
      case _PERFSEL2:
        return perfSel[2];
      case _PERFCTR3:
        return perfCtr[3];
      case _PERFSEL3:
        return perfSel[3];
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _PERFCTR0:
        perfCtr[0] = 0;
        break;
      case _PERFSEL0:
        perfSel[0] = value & 0x1f;
        break;
      case _PERFCTR1:
        perfCtr[1] = 0;
        break;
      case _PERFSEL1:
        perfSel[1] = value & 0x1f;
        break;
      case _PERFCTR2:
        perfCtr[2] = 0;
        break;
      case _PERFSEL2:
        perfSel[2] = value & 0x1f;
        break;
      case _PERFCTR3:
        perfCtr[3] = 0;
        break;
      case _PERFSEL3:
        perfSel[3] = value & 0x1f;
        break;
      default:
        super.writeUint32(offset, value);
    }
  }
}
