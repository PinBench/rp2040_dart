// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'peripheral.dart';

const int _RTC_SETUP0 = 0x04;
const int _RTC_SETUP1 = 0x08;
const int _RTC_CTRL = 0x0c;
const int _IRQ_SETUP_0 = 0x10;
const int _RTC_RTC1 = 0x18;
const int _RTC_RTC0 = 0x1c;

const int _RTC_ENABLE_BITS = 0x01;
const int _RTC_ACTIVE_BITS = 0x2;
const int _RTC_LOAD_BITS = 0x10;

const int _SETUP_0_YEAR_SHIFT = 12;
const int _SETUP_0_YEAR_MASK = 0xfff;
const int _SETUP_0_MONTH_SHIFT = 8;
const int _SETUP_0_MONTH_MASK = 0xf;
const int _SETUP_0_DAY_SHIFT = 0;
const int _SETUP_0_DAY_MASK = 0x1f;

// ignore: unused_element
const int _SETUP_1_DOTW_SHIFT = 24;
// ignore: unused_element
const int _SETUP_1_DOTW_MASK = 0x7;
const int _SETUP_1_HOUR_SHIFT = 16;
const int _SETUP_1_HOUR_MASK = 0x1f;
const int _SETUP_1_MIN_SHIFT = 8;
const int _SETUP_1_MIN_MASK = 0x3f;
const int _SETUP_1_SEC_SHIFT = 0;
const int _SETUP_1_SEC_MASK = 0x3f;

const int _RTC_0_YEAR_SHIFT = 12;
const int _RTC_0_YEAR_MASK = 0xfff;
const int _RTC_0_MONTH_SHIFT = 8;
const int _RTC_0_MONTH_MASK = 0xf;
const int _RTC_0_DAY_SHIFT = 0;
const int _RTC_0_DAY_MASK = 0x1f;

const int _RTC_1_DOTW_SHIFT = 24;
const int _RTC_1_DOTW_MASK = 0x7;
const int _RTC_1_HOUR_SHIFT = 16;
const int _RTC_1_HOUR_MASK = 0x1f;
const int _RTC_1_MIN_SHIFT = 8;
const int _RTC_1_MIN_MASK = 0x3f;
const int _RTC_1_SEC_SHIFT = 0;
const int _RTC_1_SEC_MASK = 0x3f;

class RP2040RTC extends BasePeripheral implements Peripheral {
  int setup0 = 0;
  int setup1 = 0;
  int ctrl = 0;
  DateTime baseline = DateTime(2021, 1, 1);
  double baselineNanos = 0;

  RP2040RTC(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    // JS `new Date(ms)` truncates a fractional millisecond count.
    final date = DateTime.fromMillisecondsSinceEpoch(
      baseline.millisecondsSinceEpoch +
          ((rp2040.clock.nanos - baselineNanos) / 1000000).truncate(),
    );
    switch (offset) {
      case _RTC_SETUP0:
        return setup0;
      case _RTC_SETUP1:
        return setup1;
      case _RTC_CTRL:
        return ctrl;
      case _IRQ_SETUP_0:
        return 0;
      case _RTC_RTC1:
        return ((date.year & _RTC_0_YEAR_MASK) << _RTC_0_YEAR_SHIFT) |
            ((date.month & _RTC_0_MONTH_MASK) << _RTC_0_MONTH_SHIFT) |
            ((date.day & _RTC_0_DAY_MASK) << _RTC_0_DAY_SHIFT);
      case _RTC_RTC0:
        // JS getDay(): 0 = Sunday; Dart weekday: 7 = Sunday
        return (((date.weekday % 7) & _RTC_1_DOTW_MASK) << _RTC_1_DOTW_SHIFT) |
            ((date.hour & _RTC_1_HOUR_MASK) << _RTC_1_HOUR_SHIFT) |
            ((date.minute & _RTC_1_MIN_MASK) << _RTC_1_MIN_SHIFT) |
            ((date.second & _RTC_1_SEC_MASK) << _RTC_1_SEC_SHIFT);
      default:
        break;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _RTC_SETUP0:
        setup0 = value;
        break;
      case _RTC_SETUP1:
        setup1 = value;
        break;
      case _RTC_CTRL:
        // Though RTC_LOAD_BITS is type SC and should be cleared on next cycle, pico-sdk write
        // RTC_LOAD_BITS & RTC_ENABLE_BITS seperatly.
        // https://github.com/raspberrypi/pico-sdk/blob/master/src/rp2_common/hardware_rtc/rtc.c#L76-L80
        if (value & _RTC_LOAD_BITS != 0) {
          ctrl |= _RTC_LOAD_BITS;
        }
        if (value & _RTC_ENABLE_BITS != 0) {
          ctrl |= _RTC_ENABLE_BITS;
          ctrl |= _RTC_ACTIVE_BITS;
          if (ctrl & _RTC_LOAD_BITS != 0) {
            var year = (setup0 >> _SETUP_0_YEAR_SHIFT) & _SETUP_0_YEAR_MASK;
            final month =
                (setup0 >> _SETUP_0_MONTH_SHIFT) & _SETUP_0_MONTH_MASK;
            final day = (setup0 >> _SETUP_0_DAY_SHIFT) & _SETUP_0_DAY_MASK;
            final hour = (setup1 >> _SETUP_1_HOUR_SHIFT) & _SETUP_1_HOUR_MASK;
            final min = (setup1 >> _SETUP_1_MIN_SHIFT) & _SETUP_1_MIN_MASK;
            final sec = (setup1 >> _SETUP_1_SEC_SHIFT) & _SETUP_1_SEC_MASK;
            // JS `new Date(year, ...)` maps years 0..99 to 1900..1999.
            if (year <= 99) {
              year += 1900;
            }
            // JS months are 0-based (`month - 1`), Dart's 1-based; both roll over out-of-range values.
            baseline = DateTime(year, month, day, hour, min, sec);
            baselineNanos = rp2040.clock.nanos;
            ctrl &= ~_RTC_LOAD_BITS;
          }
        } else {
          ctrl &= ~_RTC_ENABLE_BITS;
          ctrl &= ~_RTC_ACTIVE_BITS;
        }
        break;
      default:
        super.writeUint32(offset, value);
    }
  }
}
