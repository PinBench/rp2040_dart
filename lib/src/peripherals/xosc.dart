// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// The register map is kept whole, as in rp2040js, including the constants
// this file does not use yet.
// ignore_for_file: unused_element

import '../utils/bit.dart';
import 'peripheral.dart';

// XOSC register offsets
const _XOSC_CTRL = 0x00;
const _XOSC_STATUS = 0x04;
const _XOSC_DORMANT = 0x08;
const _XOSC_STARTUP = 0x0c;
const _XOSC_COUNT = 0x1c;

// CTRL register bits
const _CTRL_ENABLE_LSB = 12;
const _CTRL_ENABLE_BITS = 0x00fff000;
const _CTRL_FREQ_RANGE_BITS = 0x00000fff;

// CTRL ENABLE values
const _CTRL_ENABLE_DISABLE = 0xd1e;
const _CTRL_ENABLE_ENABLE = 0xfab;

// STATUS register bits
const _STATUS_STABLE = 0x80000000; // bit 31
const _STATUS_BADWRITE = 0x01000000; // bit 24
const _STATUS_ENABLED = 0x00001000; // bit 12
const _STATUS_FREQ_RANGE_BITS = 0x00000003;

// DORMANT register values
const _DORMANT_VALUE = 0x636f6d61; // "coma" in ASCII
const _WAKE_VALUE = 0x77616b65; // "wake" in ASCII

// STARTUP register bits
const _STARTUP_X4 = 0x00100000; // bit 20
const _STARTUP_DELAY_BITS = 0x00003fff;

class RPXOSC extends BasePeripheral implements Peripheral {
  int _ctrl = 0;
  int _status = 0;
  int _dormant = 0;
  int _startup = 0;
  int _count = 0;
  bool _enabled = false;
  bool _stable = false;
  bool _isDormant = false;

  RPXOSC(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _XOSC_CTRL:
        return _ctrl;

      case _XOSC_STATUS:
        {
          var status = _status;
          if (_stable) {
            status = u32(status | _STATUS_STABLE);
          }
          if (_enabled) {
            status |= _STATUS_ENABLED;
          }
          return status;
        }

      case _XOSC_DORMANT:
        return _dormant;

      case _XOSC_STARTUP:
        return _startup;

      case _XOSC_COUNT:
        return _count;
    }

    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _XOSC_CTRL:
        {
          _ctrl = value;
          final enableValue = (value & _CTRL_ENABLE_BITS) >>> _CTRL_ENABLE_LSB;
          // Currently unused, but could be logged or validated
          // ignore: unused_local_variable
          final freqRange = value & _CTRL_FREQ_RANGE_BITS;

          if (enableValue == _CTRL_ENABLE_ENABLE) {
            if (!_isDormant) {
              _enabled = true;
              // For simplicity, become stable immediately
              // In real hardware, this would take time based on STARTUP register
              _stable = true;
            }
          } else if (enableValue == _CTRL_ENABLE_DISABLE) {
            _enabled = false;
            _stable = false;
          } else if (enableValue != 0) {
            // Invalid write to ENABLE field
            _status |= _STATUS_BADWRITE;
            warn(
              'Invalid ENABLE value written: 0x${enableValue.toRadixString(16)}',
            );
          }
          break;
        }

      case _XOSC_STATUS:
        // Clear BADWRITE bit if written as 1 (write-1-to-clear)
        if (value & _STATUS_BADWRITE != 0) {
          _status &= ~_STATUS_BADWRITE;
        }
        break;

      case _XOSC_DORMANT:
        if (value == _DORMANT_VALUE) {
          _isDormant = true;
          _stable = false;
        } else if (value == _WAKE_VALUE) {
          _isDormant = false;
          if (_enabled) {
            _stable = true;
          }
        }
        _dormant = value;
        break;

      case _XOSC_STARTUP:
        _startup = value & (_STARTUP_X4 | _STARTUP_DELAY_BITS);
        break;

      case _XOSC_COUNT:
        // Writing to COUNT starts the countdown
        _count = value & 0xff;
        // For simplicity, we don't actually implement the countdown
        // In real hardware, this would decrement at the XOSC frequency
        break;

      default:
        super.writeUint32(offset, value);
    }
  }
}
