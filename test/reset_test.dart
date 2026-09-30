// SPDX-License-Identifier: MIT
// Copyright (c) PinBench

import 'package:rp2040_dart/src/rp2040.dart';
import 'package:test/test.dart';

void main() {
  test('reset erases every byte of flash to 0xff', () {
    final rp2040 = RP2040();
    rp2040.flash[0] = 0;
    rp2040.flash[12345] = 0x5a;
    rp2040.flash[rp2040.flash.length - 1] = 1;
    rp2040.reset();
    expect(rp2040.flash.every((byte) => byte == 0xff), isTrue);
  });
}
