// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// The register map is kept whole, as in rp2040js, including the constants
// this file does not use yet.
// ignore_for_file: unused_element

import 'dart:typed_data';

import '../utils/timer32.dart';
import 'peripheral.dart';

const _CTRL = 0x00; // Control register
const _LOAD = 0x04; // Load the watchdog timer.
const _REASON = 0x08; // Logs the reason for the last reset.
const _SCRATCH0 = 0x0c; // Scratch register
const _SCRATCH1 = 0x10; // Scratch register
const _SCRATCH2 = 0x14; // Scratch register
const _SCRATCH3 = 0x18; // Scratch register
const _SCRATCH4 = 0x1c; // Scratch register
const _SCRATCH5 = 0x20; // Scratch register
const _SCRATCH6 = 0x24; // Scratch register
const _SCRATCH7 = 0x28; // Scratch register
const _TICK = 0x2c; // Controls the tick generator

// CTRL bits:
const _TRIGGER = 0x80000000; // 1 << 31
const _ENABLE = 1 << 30;
const _PAUSE_DBG1 = 1 << 26;
const _PAUSE_DBG0 = 1 << 25;
const _PAUSE_JTAG = 1 << 24;
const _TIME_MASK = 0xffffff;
const _TIME_SHIFT = 0;

// LOAD bits
const _LOAD_MASK = 0xffffff;
const _LOAD_SHIFT = 0;

// REASON bits:
const _FORCE = 1 << 1;
const _TIMER = 1 << 0;

// TICK bits:
const _COUNT_MASK = 0x1ff;
const _COUNT_SHIFT = 11;
const _RUNNING = 1 << 10;
const _TICK_ENABLE = 1 << 9;
const _CYCLES_MASK = 0x1ff;
const _CYCLES_SHIFT = 0;

const double _TICK_FREQUENCY =
    2000000; // Actually 1 MHz, but due to errata RP2040-E1, the timer is decremented twice per tick

class RPWatchdog extends BasePeripheral implements Peripheral {
  final Timer32 timer;
  late final Timer32PeriodicAlarm alarm;
  final Uint32List scratchData = Uint32List(8);

  bool _enable = false;
  bool _tickEnable = true;
  int _reason = 0;
  bool _pauseDbg0 = true;
  bool _pauseDbg1 = true;
  bool _pauseJtag = true;

  /// Called when the watchdog triggers - override with your own soft reset implementation
  void Function()? onWatchdogTrigger;

  // User provided
  RPWatchdog(super.rp2040, super.name)
    : timer = Timer32(rp2040.clock, _TICK_FREQUENCY) {
    onWatchdogTrigger = () {
      rp2040.logger.warn(
        name,
        'Watchdog triggered, but no reset handler provided',
      );
    };
    timer.mode = TimerMode.Decrement;
    timer.enable = false;
    alarm = Timer32PeriodicAlarm(timer, () {
      _reason = _TIMER;
      onWatchdogTrigger?.call();
    });
    alarm.target = 0;
    alarm.enable = false;
  }

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _CTRL:
        return (timer.enable ? _ENABLE : 0) |
            (_pauseDbg0 ? _PAUSE_DBG0 : 0) |
            (_pauseDbg1 ? _PAUSE_DBG1 : 0) |
            (_pauseJtag ? _PAUSE_JTAG : 0) |
            ((timer.counter & _TIME_MASK) << _TIME_SHIFT);

      case _REASON:
        return _reason;

      case _SCRATCH0:
      case _SCRATCH1:
      case _SCRATCH2:
      case _SCRATCH3:
      case _SCRATCH4:
      case _SCRATCH5:
      case _SCRATCH6:
      case _SCRATCH7:
        return scratchData[(offset - _SCRATCH0) >> 2];

      case _TICK:
        // TODO COUNT bits
        return _tickEnable ? _RUNNING | _TICK_ENABLE : 0;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _CTRL:
        if (value & _TRIGGER != 0) {
          _reason = _FORCE;
          onWatchdogTrigger?.call();
        }
        _enable = value & _ENABLE != 0;
        timer.enable = _enable && _tickEnable;
        alarm.enable = _enable && _tickEnable;
        _pauseDbg0 = value & _PAUSE_DBG0 != 0;
        _pauseDbg1 = value & _PAUSE_DBG1 != 0;
        _pauseJtag = value & _PAUSE_JTAG != 0;
        break;

      case _LOAD:
        timer.set((value >>> _LOAD_SHIFT) & _LOAD_MASK);
        break;

      case _SCRATCH0:
      case _SCRATCH1:
      case _SCRATCH2:
      case _SCRATCH3:
      case _SCRATCH4:
      case _SCRATCH5:
      case _SCRATCH6:
      case _SCRATCH7:
        scratchData[(offset - _SCRATCH0) >> 2] = value;
        break;

      case _TICK:
        _tickEnable = value & _TICK_ENABLE != 0;
        timer.enable = _enable && _tickEnable;
        alarm.enable = _enable && _tickEnable;
        // TODO - handle CYCLES (tick also affectes timer)
        break;

      default:
        super.writeUint32(offset, value);
    }
  }
}
