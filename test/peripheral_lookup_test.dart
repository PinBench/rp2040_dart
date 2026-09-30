// SPDX-License-Identifier: MIT
// Copyright (c) PinBench

import 'package:rp2040_dart/src/peripherals/peripheral.dart';
import 'package:rp2040_dart/src/rp2040.dart';
import 'package:test/test.dart';

/// `findPeripheral` reads a dense array kept beside the `peripherals` map;
/// it must always answer what rp2040js's `peripherals[(address >>> 14) << 2]`
/// would.
void main() {
  void expectMatchesMap(RP2040 rp2040) {
    for (var block = 0; block < 1 << 18; block++) {
      final address = block << 14;
      final expected = rp2040.peripherals[(address >>> 14) << 2];
      if (!identical(rp2040.findPeripheral(address), expected) ||
          !identical(rp2040.findPeripheral(address + 0x3ffc), expected)) {
        fail(
          'findPeripheral(0x${address.toRadixString(16)}) disagrees with the map',
        );
      }
    }
  }

  test(
    'findPeripheral agrees with the peripherals map at every 16 KB block',
    () {
      expectMatchesMap(RP2040());
    },
  );

  test('and still does after entries are added, replaced and removed', () {
    final rp2040 = RP2040();
    final extra = UnimplementedPeripheral(rp2040, 'extra');
    rp2040.peripherals[0x10] = extra; // what rp2040.spec does
    rp2040.peripherals[0x40034] = extra; // replace UART0
    rp2040.peripherals[0x13] = extra; // not a multiple of 4: unreachable
    rp2040.peripherals.remove(0x4004c); // ADC
    expectMatchesMap(rp2040);
    expect(
      rp2040.findPeripheral(0x10000),
      same(extra),
    ); // key 0x10 = (0x10000 >>> 14) << 2
    expect(rp2040.findPeripheral(0x40034000), same(extra));
    expect(rp2040.findPeripheral(0x4004c000), isNull);
  });
}
