// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/peripherals/uart.dart';
import 'package:rp2040_dart/src/rp2040.dart';
import 'package:test/test.dart';

const int UARTIBRD = 0x24;
const int UARTFBRD = 0x28;
const int OFFSET_UARTLCR_H = 0x2c;

void main() {
  group('UART', () {
    test('should correctly return wordLength based on UARTLCR_H value', () {
      final rp2040 = RP2040();
      final uart = RPUART(
        rp2040,
        'UART',
        0,
        const IUARTDMAChannels(rx: 0, tx: 0),
      );
      uart.writeUint32(OFFSET_UARTLCR_H, 0x70);
      expect(uart.wordLength, 8);
    });

    test(
      'should correctly calculate the baud rate based on UARTIBRD, UARTFBRD values',
      () {
        final rp2040 = RP2040();
        final uart = RPUART(
          rp2040,
          'UART',
          0,
          const IUARTDMAChannels(rx: 0, tx: 0),
        );
        uart.writeUint32(
          UARTIBRD,
          67,
        ); // Values taken from example in section 4.2.7.1. of the datasheet
        uart.writeUint32(UARTFBRD, 52);
        expect(uart.baudRate, 115207);
      },
    );
  });
}
