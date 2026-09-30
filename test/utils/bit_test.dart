// SPDX-License-Identifier: MIT
// Copyright (c) PinBench

import 'package:rp2040_dart/src/utils/bit.dart';
import 'package:test/test.dart';

void main() {
  group('bit helpers', () {
    test('u32 wraps negatives and values past 32 bits', () {
      expect(u32(-1), 0xffffffff);
      expect(u32(0x1_0000_0001), 1);
      expect(u32(1 << 31), 0x80000000);
    });

    test('s32 reads bit 31 as the sign', () {
      expect(s32(0xffffffff), -1);
      expect(s32(0x80000000), -2147483648);
      expect(s32(0x7fffffff), 0x7fffffff);
    });

    test('bit(31) is unsigned', () {
      expect(bit(31), 0x80000000);
    });

    test('imul matches Math.imul, as an unsigned result', () {
      // Expected values from JavaScript: Math.imul(a, b) >>> 0.
      expect(imul(3, 4), 12);
      expect(imul(0xffffffff, 5), 0xfffffffb); // -1 * 5
      expect(imul(0xfffffffe, 0xfffffffe), 4); // -2 * -2
      expect(imul(0x12345678, 0x9abcdef0), 0x242d2080);
      expect(imul(0x7fffffff, 0x7fffffff), 1);
      expect(imul(0xdeadbeef, 0xcafebabe), 0x88cf5b62);
    });
  });
}
