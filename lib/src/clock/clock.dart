// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

typedef AlarmCallback = void Function();

abstract interface class IAlarm {
  void schedule(double deltaNanos);
  void cancel();
}

abstract interface class IClock {
  double get nanos;

  IAlarm createAlarm(AlarmCallback callback);
}
