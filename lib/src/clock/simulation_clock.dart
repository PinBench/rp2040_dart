// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'clock.dart';

typedef ClockEventCallback = void Function();

class ClockAlarm implements IAlarm {
  ClockAlarm? next;
  double nanos = 0;
  bool scheduled = false;

  final SimulationClock _clock;
  final AlarmCallback callback;

  ClockAlarm(this._clock, this.callback);

  @override
  void schedule(double deltaNanos) {
    if (scheduled) {
      cancel();
    }
    _clock.linkAlarm(deltaNanos, this);
  }

  @override
  void cancel() {
    _clock.unlinkAlarm(this);
    scheduled = false;
  }
}

class SimulationClock implements IClock {
  ClockAlarm? _nextAlarm;

  double _nanosCounter = 0;

  final double frequency;

  SimulationClock([this.frequency = 125e6]);

  @override
  double get nanos => _nanosCounter;

  double get micros => nanos / 1000;

  @override
  ClockAlarm createAlarm(ClockEventCallback callback) =>
      ClockAlarm(this, callback);

  ClockAlarm linkAlarm(double nanos, ClockAlarm alarm) {
    alarm.nanos = this.nanos + nanos;
    var alarmListItem = _nextAlarm;
    ClockAlarm? lastItem;
    while (alarmListItem != null && alarmListItem.nanos < alarm.nanos) {
      lastItem = alarmListItem;
      alarmListItem = alarmListItem.next;
    }
    if (lastItem != null) {
      lastItem.next = alarm;
      alarm.next = alarmListItem;
    } else {
      _nextAlarm = alarm;
      alarm.next = alarmListItem;
    }
    alarm.scheduled = true;
    return alarm;
  }

  bool unlinkAlarm(ClockAlarm alarm) {
    var alarmListItem = _nextAlarm;
    if (alarmListItem == null) {
      return false;
    }
    ClockAlarm? lastItem;
    while (alarmListItem != null) {
      if (identical(alarmListItem, alarm)) {
        if (lastItem != null) {
          lastItem.next = alarmListItem.next;
        } else {
          _nextAlarm = alarmListItem.next;
        }
        return true;
      }
      lastItem = alarmListItem;
      alarmListItem = alarmListItem.next;
    }
    return false;
  }

  void tick(double deltaNanos) {
    final targetNanos = _nanosCounter + deltaNanos;
    var alarm = _nextAlarm;
    while (alarm != null && alarm.nanos <= targetNanos) {
      _nextAlarm = alarm.next;
      _nanosCounter = alarm.nanos;
      alarm.callback();
      alarm = _nextAlarm;
    }
    _nanosCounter = targetNanos;
  }

  double get nanosToNextAlarm {
    final nextAlarm = _nextAlarm;
    if (nextAlarm != null) {
      return nextAlarm.nanos - nanos;
    }
    return 0;
  }
}
