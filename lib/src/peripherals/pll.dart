// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import '../utils/bit.dart';
import 'peripheral.dart';

// PLL register offsets
const _PLL_CS = 0x00; // Control and Status
const _PLL_PWR = 0x04; // Power control
const _PLL_FBDIV_INT = 0x08; // Feedback divisor
const _PLL_PRIM = 0x0c; // Primary post dividers

// PLL_CS bits
const _PLL_CS_LOCK = 0x80000000; // 1 << 31
const _PLL_CS_BYPASS = 1 << 8;
const _PLL_CS_REFDIV_MASK = 0x3f;

// PLL_FBDIV_INT bits
const _PLL_FBDIV_INT_MASK = 0xfff;

// PLL_PRIM bits
const _PLL_PRIM_POSTDIV1_SHIFT = 16;
const _PLL_PRIM_POSTDIV2_SHIFT = 12;
const _PLL_PRIM_POSTDIV_MASK = 0x7;

/// RP2040 PLL peripheral.
///
/// Always reports locked (we have no startup delay to model), and computes its output
/// frequency from the divider registers:
///
///   f_out = (f_ref / REFDIV * FBDIV) / (POSTDIV1 * POSTDIV2)
///
/// The frequency is what makes `RP2040.clkSys` follow `set_sys_clock_khz()` and friends.
class RPPLL extends BasePeripheral implements Peripheral {
  int _cs = 0x1; // REFDIV = 1
  int _pwr = 0x2d; // VCO and post dividers powered down
  int _fbdivInt = 0;
  int _prim = 0x77000; // POSTDIV1 = 7, POSTDIV2 = 7

  RPPLL(super.rp2040, super.name);

  int get refdiv => _cs & _PLL_CS_REFDIV_MASK;

  int get fbdiv => _fbdivInt & _PLL_FBDIV_INT_MASK;

  int get postdiv1 =>
      (_prim >>> _PLL_PRIM_POSTDIV1_SHIFT) & _PLL_PRIM_POSTDIV_MASK;

  int get postdiv2 =>
      (_prim >>> _PLL_PRIM_POSTDIV2_SHIFT) & _PLL_PRIM_POSTDIV_MASK;

  /// PLL output frequency, in Hz, derived from the current register values.
  double get frequency {
    final refFreq = rp2040.xoscFreq / (refdiv != 0 ? refdiv : 1);
    if (_cs & _PLL_CS_BYPASS != 0) {
      return refFreq;
    }
    final postdiv =
        (postdiv1 != 0 ? postdiv1 : 1) * (postdiv2 != 0 ? postdiv2 : 1);
    return (refFreq * fbdiv) / postdiv;
  }

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _PLL_CS:
        return u32(_cs | _PLL_CS_LOCK);
      case _PLL_PWR:
        return _pwr;
      case _PLL_FBDIV_INT:
        return _fbdivInt;
      case _PLL_PRIM:
        return _prim;
      default:
        return super.readUint32(offset);
    }
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _PLL_CS:
        _cs = value;
        break;
      case _PLL_PWR:
        _pwr = value;
        break;
      case _PLL_FBDIV_INT:
        _fbdivInt = value;
        break;
      case _PLL_PRIM:
        _prim = value;
        break;
      default:
        super.writeUint32(offset, value);
        return;
    }
    rp2040.updateClocks();
  }
}
