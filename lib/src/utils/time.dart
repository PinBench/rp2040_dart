// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

final Stopwatch _clock = Stopwatch()..start();

int getCurrentMicroseconds() => _clock.elapsedMicroseconds;

String _leftPad(String value, int minLength, [String padChar = ' ']) {
  if (value.length < minLength) {
    value = padChar + value;
  }
  return value;
}

String _rightPad(String value, int minLength, [String padChar = ' ']) {
  if (value.length < minLength) {
    value += padChar;
  }
  return value;
}

String formatTime(DateTime date) {
  final hours = _leftPad(date.hour.toString(), 2, '0');
  final minutes = _leftPad(date.minute.toString(), 2, '0');
  final seconds = _leftPad(date.second.toString(), 2, '0');
  final milliseconds = _rightPad(date.millisecond.toString(), 3);
  return '$hours:$minutes:$seconds.$milliseconds';
}
