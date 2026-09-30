// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/utils/time.dart';
import 'package:test/test.dart';

void main() {
  group('formatTime', () {
    test(
      'should correctly format a timestamp with microseconds, padding with spaces',
      () {
        // JS months are 0-based: `new Date(2020, 10, ...)` is November
        expect(
          formatTime(DateTime(2020, 11, 10, 4, 55, 2, 12)),
          '04:55:02.12 ',
        );
      },
    );
  });
}
