// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// The register map is kept whole, as in rp2040js, including the constants
// this file does not use yet.
// ignore_for_file: unused_element

import '../clock/clock.dart';
import '../irq.dart';
import '../utils/bit.dart';
import 'peripheral.dart';

const _TIMEHR = 0x08;
const _TIMELR = 0x0c;
const _TIMERAWH = 0x24;
const _TIMERAWL = 0x28;
const _ALARM0 = 0x10;
const _ALARM1 = 0x14;
const _ALARM2 = 0x18;
const _ALARM3 = 0x1c;
const _ARMED = 0x20;
const _PAUSE = 0x30;
const _INTR = 0x34;
const _INTE = 0x38;
const _INTF = 0x3c;
const _INTS = 0x40;

const _ALARM_0 = 1 << 0;
const _ALARM_1 = 1 << 1;
const _ALARM_2 = 1 << 2;
const _ALARM_3 = 1 << 3;

const _timerInterrupts = [IRQ.TIMER_0, IRQ.TIMER_1, IRQ.TIMER_2, IRQ.TIMER_3];

class _RPTimerAlarm {
  bool armed = false;
  int targetMicros = 0;

  final int bitValue;
  final IAlarm clockAlarm;

  _RPTimerAlarm(this.bitValue, this.clockAlarm);
}

class RPTimer extends BasePeripheral implements Peripheral {
  final IClock _clock;
  int _latchedTimeHigh = 0;
  late final List<_RPTimerAlarm> _alarms;
  int _intRaw = 0;
  int _intEnable = 0;
  int _intForce = 0;
  bool _paused = false;

  RPTimer(super.rp2040, super.name) : _clock = rp2040.clock {
    _alarms = [
      _RPTimerAlarm(_ALARM_0, _clock.createAlarm(() => _fireAlarm(0))),
      _RPTimerAlarm(_ALARM_1, _clock.createAlarm(() => _fireAlarm(1))),
      _RPTimerAlarm(_ALARM_2, _clock.createAlarm(() => _fireAlarm(2))),
      _RPTimerAlarm(_ALARM_3, _clock.createAlarm(() => _fireAlarm(3))),
    ];
  }

  int get intStatus => (_intRaw & _intEnable) | _intForce;

  @override
  int readUint32(int offset) {
    final time = _clock.nanos / 1000;

    switch (offset) {
      case _TIMEHR:
        return _latchedTimeHigh;

      case _TIMELR:
        _latchedTimeHigh = (time / 4294967296).floor(); // 2 ** 32
        return u32(time.toInt());

      case _TIMERAWH:
        return (time / 4294967296).floor(); // 2 ** 32

      case _TIMERAWL:
        return u32(time.toInt());

      case _ALARM0:
        return _alarms[0].targetMicros;
      case _ALARM1:
        return _alarms[1].targetMicros;
      case _ALARM2:
        return _alarms[2].targetMicros;
      case _ALARM3:
        return _alarms[3].targetMicros;

      case _PAUSE:
        return _paused ? 1 : 0;

      case _INTR:
        return _intRaw;
      case _INTE:
        return _intEnable;
      case _INTF:
        return _intForce;
      case _INTS:
        return intStatus;

      case _ARMED:
        return (_alarms[0].armed ? _alarms[0].bitValue : 0) |
            (_alarms[1].armed ? _alarms[1].bitValue : 0) |
            (_alarms[2].armed ? _alarms[2].bitValue : 0) |
            (_alarms[3].armed ? _alarms[3].bitValue : 0);
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _ALARM0:
      case _ALARM1:
      case _ALARM2:
      case _ALARM3:
        {
          final alarmIndex = (offset - _ALARM0) ~/ 4;
          final alarm = _alarms[alarmIndex];
          // TS `>>> 0` of a fractional double: truncate towards zero, then wrap to 32 bits
          final deltaMicros = u32((value - _clock.nanos / 1000).toInt());
          alarm.armed = true;
          alarm.targetMicros = value;
          alarm.clockAlarm.schedule(deltaMicros * 1000.0);
          break;
        }
      case _ARMED:
        for (final alarm in _alarms) {
          if (rawWriteValue & alarm.bitValue != 0) {
            _disarmAlarm(alarm);
          }
        }
        break;
      case _PAUSE:
        _paused = value & 1 != 0;
        if (_paused) {
          warn('Unimplemented Timer Pause');
        }
        // TODO actually pause the timer
        break;
      case _INTR:
        _intRaw &= ~rawWriteValue;
        _checkInterrupts();
        break;
      case _INTE:
        _intEnable = value & 0xf;
        _checkInterrupts();
        break;
      case _INTF:
        _intForce = value & 0xf;
        _checkInterrupts();
        break;
      default:
        super.writeUint32(offset, value);
    }
  }

  void _fireAlarm(int index) {
    final alarm = _alarms[index];
    _disarmAlarm(alarm);
    _intRaw |= alarm.bitValue;
    _checkInterrupts();
  }

  void _checkInterrupts() {
    final intStatus = this.intStatus;
    for (var i = 0; i < _alarms.length; i++) {
      rp2040.setInterrupt(_timerInterrupts[i], intStatus & (1 << i) != 0);
    }
  }

  void _disarmAlarm(_RPTimerAlarm alarm) {
    alarm.clockAlarm.cancel();
    alarm.armed = false;
  }
}
