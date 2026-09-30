// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import '../clock/clock.dart';
import 'bit.dart';

enum TimerMode { Increment, Decrement, ZigZag }

/// JS `Math.round(x)`: rounds half-way cases towards +Infinity (Dart's
/// `round()` rounds them away from zero, which differs for negative values).
int _jsRound(double x) {
  final floor = x.floorToDouble();
  return (x - floor >= 0.5 ? floor + 1 : floor).toInt();
}

class Timer32 {
  int _baseValue = 0;
  double _baseNanos = 0;
  int _topValue = 0xffffffff;
  double _prescalerValue = 1;
  TimerMode _timerMode = TimerMode.Increment;
  bool _enabled = true;
  final List<void Function()> listeners = [];

  final IClock clock;
  double _baseFreq;

  Timer32(this.clock, double baseFreq) : _baseFreq = baseFreq;

  void reset() {
    _baseNanos = clock.nanos;
    _baseValue = 0;
    _updated();
  }

  void set(int value, [bool zigZagDown = false]) {
    _baseValue = zigZagDown ? _topValue * 2 - value : value;
    _baseNanos = clock.nanos;
    _updated();
  }

  /// Advances the counter by the given amount. Note that this will
  /// decrease the counter if the timer is running in Decrement mode.
  ///
  /// @param delta The value to add to the counter. Can be negative.
  void advance(int delta) {
    _baseValue += delta;
    if (_topValue != 0xffffffff) {
      // Keep the base value in range, so that retarding past 0 wraps around to the top
      final topModulo = _timerMode == TimerMode.ZigZag
          ? _topValue * 2
          : _topValue + 1;
      // JS `x % 0` is NaN (ZigZag with top 0), which `counter` reads back as 0.
      _baseValue = topModulo != 0
          ? (_baseValue.remainder(topModulo) + topModulo).remainder(topModulo)
          : 0;
    }
    _updated();
  }

  int get rawCounter {
    final baseFreq = _baseFreq;
    final prescalerValue = _prescalerValue;
    final baseNanos = _baseNanos;
    final baseValue = _baseValue;
    final enabled = _enabled;
    final timerMode = _timerMode;
    if (baseFreq == 0 || prescalerValue == 0 || !enabled) {
      return _baseValue;
    }
    final zigzag = timerMode == TimerMode.ZigZag;
    final ticks =
        ((clock.nanos - baseNanos) / 1e9) * (baseFreq / prescalerValue);
    final topModulo = zigzag ? _topValue * 2 : _topValue + 1;
    final delta = timerMode == TimerMode.Decrement
        ? topModulo - ticks.remainder(topModulo)
        : ticks;
    var currentValue = _jsRound(baseValue + delta);
    if (_topValue != 0xffffffff) {
      // JS `x % 0` is NaN (ZigZag with top 0), which `counter` reads back as 0.
      currentValue = topModulo != 0 ? currentValue.remainder(topModulo) : 0;
    }
    return currentValue;
  }

  int get counter {
    var currentValue = rawCounter;
    if (_timerMode == TimerMode.ZigZag && currentValue > _topValue) {
      currentValue = _topValue * 2 - currentValue;
    }
    return u32(currentValue);
  }

  int get top => _topValue;

  set top(int value) {
    final counter = this.counter;
    _topValue = value;
    set(counter <= _topValue ? counter : 0);
  }

  double get frequency => _baseFreq;

  set frequency(double value) {
    _baseValue = counter;
    _baseNanos = clock.nanos;
    _baseFreq = value;
    _updated();
  }

  double get prescaler => _prescalerValue;

  set prescaler(double value) {
    _baseValue = counter;
    _baseNanos = clock.nanos;
    _enabled = _prescalerValue != 0;
    _prescalerValue = value;
    _updated();
  }

  double toNanos(int cycles) {
    final baseFreq = _baseFreq;
    final prescalerValue = _prescalerValue;
    return (cycles * 1e9) / (baseFreq / prescalerValue);
  }

  bool get enable => _enabled;

  set enable(bool value) {
    if (value != _enabled) {
      if (value) {
        _baseNanos = clock.nanos;
      } else {
        _baseValue = counter;
      }
      _enabled = value;
      _updated();
    }
  }

  TimerMode get mode => _timerMode;

  set mode(TimerMode value) {
    if (_timerMode != value) {
      final counter = this.counter;
      _timerMode = value;
      set(counter);
    }
  }

  void _updated() {
    for (final listener in listeners) {
      listener();
    }
  }
}

class Timer32PeriodicAlarm {
  int _targetValue = 0;
  bool _enabled = false;
  late final IAlarm _clockAlarm;

  final Timer32 timer;
  final void Function() callback;

  Timer32PeriodicAlarm(this.timer, this.callback) {
    _clockAlarm = timer.clock.createAlarm(handleAlarm);
    timer.listeners.add(update);
  }

  bool get enable => _enabled;

  set enable(bool value) {
    if (value != _enabled) {
      _enabled = value;
      if (value && timer.enable) {
        _schedule();
      } else {
        _cancel();
      }
    }
  }

  int get target => _targetValue;

  set target(int value) {
    if (value == _targetValue) {
      return;
    }
    _targetValue = value;
    if (_enabled && timer.enable) {
      _cancel();
      _schedule();
    }
  }

  void handleAlarm() {
    callback();
    if (_enabled && timer.enable) {
      _schedule();
    }
  }

  void update() {
    _cancel();
    if (_enabled && timer.enable) {
      _schedule();
    }
  }

  void _schedule() {
    final timer = this.timer;
    final targetValue = _targetValue;
    final top = timer.top;
    final mode = timer.mode;
    final rawCounter = timer.rawCounter;
    var cycleDelta = targetValue - rawCounter;
    if (mode == TimerMode.ZigZag && cycleDelta < 0) {
      if (cycleDelta < -top) {
        cycleDelta += 2 * top;
      } else {
        cycleDelta = top * 2 - targetValue - rawCounter;
      }
    }
    if (top != 0xffffffff) {
      if (cycleDelta <= 0) {
        cycleDelta += top + 1;
      }
      if (targetValue > top) {
        // Skip alarm
        return;
      }
    }
    if (mode == TimerMode.Decrement) {
      cycleDelta = top + 1 - cycleDelta;
    }
    final cyclesToAlarm = u32(cycleDelta);
    final nanosToAlarm = timer.toNanos(cyclesToAlarm);
    _clockAlarm.schedule(nanosToAlarm);
  }

  void _cancel() {
    _clockAlarm.cancel();
  }
}
