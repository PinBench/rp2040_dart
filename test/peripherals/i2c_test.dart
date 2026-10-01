// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/rp2040.dart';
import 'package:test/test.dart';

const int IC_TAR = 0x04;
const int IC_DATA_CMD = 0x10;
const int IC_RAW_INTR_STAT = 0x34;
const int IC_ENABLE = 0x6c;
const int IC_TX_ABRT_SOURCE = 0x80;

const int R_TX_EMPTY = 1 << 4;
const int R_TX_ABRT = 1 << 6;
const int ABRT_7B_ADDR_NOACK = 1 << 0;
const int STOP = 1 << 9;

/// Not in rp2040js: it has no I2C spec. Covers rp2040_dart's one deviation
/// from it in this peripheral, TX_EMPTY after an abort.
void main() {
  group('I2C', () {
    test('a NACKed address aborts and leaves TX_EMPTY raised', () {
      final rp2040 = RP2040();
      final i2c = rp2040.i2c[0];
      // No device answers: the address is NACKed.
      i2c.onConnect = (address, mode) => i2c.completeConnect(false);

      i2c.writeUint32(IC_ENABLE, 1);
      i2c.writeUint32(IC_TAR, 0x3c);
      i2c.writeUint32(IC_DATA_CMD, 0x42 | STOP);

      final raw = i2c.readUint32(IC_RAW_INTR_STAT);
      expect(raw & R_TX_ABRT, R_TX_ABRT);
      expect(
        i2c.readUint32(IC_TX_ABRT_SOURCE) & ABRT_7B_ADDR_NOACK,
        ABRT_7B_ADDR_NOACK,
      );
      // The abort flushed the TX FIFO, and an empty FIFO is TX_EMPTY: the
      // pico-sdk waits on it after every byte, so without it a NACK cost the
      // sketch its whole timeout.
      expect(raw & R_TX_EMPTY, R_TX_EMPTY);
    });

    test(
      'an acknowledged write still clears TX_EMPTY while a byte is queued',
      () {
        final rp2040 = RP2040();
        final i2c = rp2040.i2c[0];
        // A device that ACKs its address but never finishes the byte, so the
        // command stays pending.
        i2c.onConnect = (address, mode) => i2c.completeConnect(true);
        i2c.onWriteByte = (value) {};

        i2c.writeUint32(IC_ENABLE, 1);
        i2c.writeUint32(IC_TAR, 0x3c);
        i2c.writeUint32(IC_DATA_CMD, 0x42);
        i2c.writeUint32(IC_DATA_CMD, 0x43 | STOP);

        // The fix raises TX_EMPTY on an abort only; a queued byte still
        // holds it down, as rp2040js has it.
        final raw = i2c.readUint32(IC_RAW_INTR_STAT);
        expect(raw & R_TX_ABRT, 0);
        expect(raw & R_TX_EMPTY, 0);
      },
    );
  });
}
