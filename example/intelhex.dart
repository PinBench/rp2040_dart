// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

/*
 * Minimal Intel HEX loader
 * Part of AVR8js
 *
 * Copyright (C) 2019, Uri Shaked
 */

import 'dart:typed_data';

import 'package:rp2040_dart/src/gdb/gdb_utils.dart' show parseHexInt;

/// JS `str.substr(start, length)`, clamped to the string.
String _substr(String s, int start, int length) {
  if (start >= s.length) {
    return '';
  }
  final end = start + length;
  return s.substring(start, end > s.length ? s.length : end);
}

/// JS `parseInt(text, 16)`, with `NaN` as 0 (what a typed array stores for it).
int _parseHex(String text) => parseHexInt(text) ?? 0;

void loadHex(String source, Uint8List target, [int baseAddress = 0]) {
  var highAddressBytes = 0;
  for (final line in source.split('\n')) {
    if (line.startsWith(':') && _substr(line, 7, 2) == '04') {
      highAddressBytes = _parseHex(_substr(line, 9, 4));
    }
    if (line.startsWith(':') && _substr(line, 7, 2) == '00') {
      final bytes = _parseHex(_substr(line, 1, 2));
      // `|` makes a signed int32 in JS
      final addr =
          ((highAddressBytes << 16) | _parseHex(_substr(line, 3, 4))).toSigned(
            32,
          ) -
          baseAddress;
      for (var i = 0; i < bytes; i++) {
        // A typed array ignores writes out of its bounds
        if (addr + i >= 0 && addr + i < target.length) {
          target[addr + i] = _parseHex(_substr(line, 9 + i * 2, 2));
        }
      }
    }
  }
}
