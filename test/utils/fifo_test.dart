// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/utils/fifo.dart';
import 'package:test/test.dart';

void main() {
  group('FIFO', () {
    test('should successfully push and pull 4 items', () {
      final fifo = FIFO(3);
      expect(fifo.empty, true);
      fifo.push(1);
      expect(fifo.empty, false);
      fifo.push(2);
      expect(fifo.itemCount, 2);
      expect(fifo.full, false);
      fifo.push(3);
      expect(fifo.full, true);
      expect(fifo.pull(), 1);
      expect(fifo.full, false);
      fifo.push(4);
      expect(fifo.full, true);
      expect(fifo.pull(), 2);
      expect(fifo.pull(), 3);
      expect(fifo.empty, false);
      expect(fifo.itemCount, 1);
      expect(fifo.pull(), 4);
      expect(fifo.full, false);
      expect(fifo.empty, true);
    });

    group('peek()', () {
      test(
        "should return the next item in the FIFO without affecting the FIFO's content",
        () {
          final fifo = FIFO(3);
          expect(fifo.empty, true);
          fifo.push(10);
          expect(fifo.empty, false);
          fifo.push(20);
          expect(fifo.peek(), 10);
          expect(fifo.itemCount, 2);
          expect(fifo.pull(), 10);
        },
      );
    });

    group('items', () {
      test("should return an array with all the FIFO's content", () {
        final fifo = FIFO(3);
        expect(fifo.empty, true);
        fifo.push(10);
        fifo.push(20);
        fifo.push(30);
        fifo.pull();
        expect(fifo.items, [20, 30]);
      });
    });
  });
}
