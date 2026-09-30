// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'peripheral.dart';

const int _FRCE_ON = 0x00;
const int _FRCE_OFF = 0x04;
const int _WDSEL = 0x08;
const int _DONE = 0x0c;

const int _PSM_BITS_MASK = 0x0001ffff;

class RPPSM extends BasePeripheral implements Peripheral {
  int _frceOn = 0;
  int _frceOff = 0;
  int _wdsel = 0;

  RPPSM(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _FRCE_ON:
        return _frceOn;
      case _FRCE_OFF:
        return _frceOff;
      case _WDSEL:
        return _wdsel;
      case _DONE:
        // Domains are ready unless forced off (FRCE_ON overrides FRCE_OFF)
        return (_PSM_BITS_MASK & ~_frceOff) | (_frceOn & _frceOff);
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _FRCE_ON:
        _frceOn = value & _PSM_BITS_MASK;
        break;
      case _FRCE_OFF:
        _frceOff = value & _PSM_BITS_MASK;
        break;
      case _WDSEL:
        _wdsel = value & _PSM_BITS_MASK;
        break;
      default:
        super.writeUint32(offset, value);
        break;
    }
  }
}
