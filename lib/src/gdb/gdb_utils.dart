// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:typed_data';

String encodeHexByte(int value) {
  return (value >> 4).toRadixString(16) + (value & 0xf).toRadixString(16);
}

String encodeHexBuf(Uint8List buf) {
  return buf.map(encodeHexByte).join('');
}

String encodeHexUint32BE(int value) {
  return encodeHexBuf(
    Uint8List.fromList([
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]),
  );
}

String encodeHexUint32(int value) {
  final buf = Uint32List.fromList([value]);
  return encodeHexBuf(Uint8List.view(buf.buffer));
}

/// JS `parseInt(text, 16)`: parses the longest hexadecimal prefix (after
/// optional whitespace, sign and `0x`), and returns `null` where JS gives `NaN`.
int? parseHexInt(String text) {
  var s = text.trimLeft();
  var sign = 1;
  if (s.startsWith('-')) {
    sign = -1;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }
  if (s.startsWith('0x') || s.startsWith('0X')) {
    s = s.substring(2);
  }
  var result = 0;
  var digits = 0;
  for (final c in s.codeUnits) {
    int digit;
    if (c >= 0x30 && c <= 0x39) {
      digit = c - 0x30;
    } else if (c >= 0x61 && c <= 0x66) {
      digit = c - 0x61 + 10;
    } else if (c >= 0x41 && c <= 0x46) {
      digit = c - 0x41 + 10;
    } else {
      break;
    }
    result = result * 16 + digit;
    digits++;
  }
  return digits == 0 ? null : sign * result;
}

Uint8List decodeHexBuf(String encoded) {
  final result = Uint8List(encoded.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    // A NaN stored into a Uint8Array becomes 0
    result[i] = parseHexInt(encoded.substring(i * 2, i * 2 + 2)) ?? 0;
  }
  return result;
}

Uint32List decodeHexUint32Array(String encoded) {
  final bytes = decodeHexBuf(encoded);
  if (bytes.length % 4 != 0) {
    // `new Uint32Array(buffer)` throws when the length is not a multiple of 4
    throw RangeError('byte length of Uint32Array should be a multiple of 4');
  }
  return Uint32List.view(bytes.buffer);
}

int decodeHexUint32(String encoded) {
  return decodeHexUint32Array(encoded)[0];
}

String gdbChecksum(String text) {
  final value = text.codeUnits.fold(0, (a, b) => a + b) & 0xff;
  return encodeHexByte(value);
}

String gdbMessage(String value) {
  return '\$$value#${gdbChecksum(value)}';
}
