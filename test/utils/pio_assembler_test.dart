// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/utils/pio_assembler.dart';
import 'package:test/test.dart';

void main() {
  group('pio-assembler', () {
    test('should correctly encode an `jmp PIN, 5` pio instruction', () {
      expect(pioJMP(PIO_COND_PIN, 5), 0xc5);
    });

    test('should correctly encode an `wait 1 gpio 12` pio instruction', () {
      expect(pioWAIT(true, PIO_WAIT_SRC_GPIO, 12), 0x208c);
    });

    test('should correctly encode an `in X, 12` pio instruction', () {
      expect(pioIN(PIO_SRC_X, 12), 0x402c);
    });

    test('should correctly encode an `out Y, 30` pio instruction', () {
      expect(pioOUT(PIO_DEST_Y, 30), 0x605e);
    });

    test(
      'should correctly encode an `push iffull noblock` pio instruction',
      () {
        expect(pioPUSH(true, true, 12), 0x8c60);
      },
    );

    test('should correctly encode an `pull block` pio instruction', () {
      expect(pioPULL(true, false), 0x80c0);
    });

    test('should correctly encode an `mov X, !STATUS` pio instruction', () {
      expect(pioMOV(PIO_MOV_DEST_X, PIO_OP_INVERT, PIO_SRC_STATUS), 0xa02d);
    });

    test('should correctly encode an `irq set 4` pio instruction', () {
      expect(pioIRQ(false, false, 4), 0xc004);
    });

    test('should correctly encode an `set X, 12` pio instruction', () {
      expect(pioSET(PIO_MOV_DEST_X, 12), 0xe02c);
    });
  });
}
