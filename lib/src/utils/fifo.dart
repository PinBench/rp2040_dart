// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:typed_data';

class FIFO {
  final Uint32List buffer;

  int _start = 0;
  int _used = 0;

  FIFO(int size) : buffer = Uint32List(size);

  int get size => buffer.length;

  int get itemCount => _used;

  void push(int value) {
    final length = buffer.length;
    final start = _start;
    final used = _used;
    if (_used < length) {
      buffer[(start + used) % length] = value;
      _used++;
    }
  }

  int pull() {
    final start = _start;
    final used = _used;
    final length = buffer.length;
    if (used != 0) {
      _start = (start + 1) % length;
      _used--;
      return buffer[start];
    }
    return 0;
  }

  int peek() => _used != 0 ? buffer[_start] : 0;

  void reset() {
    _used = 0;
  }

  bool get empty => _used == 0;

  bool get full => _used == buffer.length;

  List<int> get items {
    final length = buffer.length;
    return [for (var i = 0; i < _used; i++) buffer[(_start + i) % length]];
  }
}
