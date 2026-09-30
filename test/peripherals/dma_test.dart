// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/clock/mock_clock.dart';
import 'package:rp2040_dart/src/rp2040.dart';
import 'package:rp2040_dart/src/utils/bit.dart';
import 'package:test/test.dart';

const CH2_WRITE_ADDR = 0x50000084;
const CH2_TRANS_COUNT = 0x50000088;
const CH2_AL1_CTRL = 0x50000090;
const CH2_AL3_READ_ADDR_TRIG = 0x500000bc;
const CH6_READ_ADDR = 0x50000180;
const CH6_WRITE_ADDR = 0x50000184;
const CH6_TRANS_COUNT = 0x50000188;
const CH6_CTRL_TRIG = 0x5000018c;
const INTR = 0x50000400;

// First offset past the 12 per-channel register blocks (12 * 0x40 = 0x300).
const DMA_BASE = 0x50000000;
const PAST_CHANNELS = DMA_BASE + 0x300;

final EN = bit(0);
const DATA_SIZE_SHIFT = 2;
final INCR_WRITE = bit(5);
final INCR_READ = bit(4);
const CHAIN_TO_SHIFT = 11;
const TREQ_SEL_SHIFT = 15;
final BUSY = bit(24);

const TREQ_PERMANENT = 0x3f;

void main() {
  group('DMA', () {
    test('should support DMA channel chaining', () {
      final clock = MockClock();
      final cpu = RP2040(clock);

      // This test uses DMA to copy 4 chunks of 8-byte data, located in different memory areas, into a single memory area.
      // We use two DMA channels, 2 and 6 (numbers are arbitrary).
      // All the RAM addresses below are arbitrary:
      const CHUNKS_ADDR = [0x20001000, 0x20001100, 0x20002200, 0x20002300];
      const DEST_ADDR = 0x20008000;
      const DMA_CONTROL_BLOCK_ADDR = 0x2000a000;

      // Write the data to be copied, split into four chunks:
      cpu.writeUint32(CHUNKS_ADDR[0], 0x10);
      cpu.writeUint32(CHUNKS_ADDR[0] + 4, 0x20);
      cpu.writeUint32(CHUNKS_ADDR[1], 0x30);
      cpu.writeUint32(CHUNKS_ADDR[1] + 4, 0x40);
      cpu.writeUint32(CHUNKS_ADDR[2], 0x50);
      cpu.writeUint32(CHUNKS_ADDR[2] + 4, 0x60);
      cpu.writeUint32(CHUNKS_ADDR[3], 0x70);
      cpu.writeUint32(CHUNKS_ADDR[3] + 4, 0x80);

      // Write the source addresses into a DMA control block:
      cpu.writeUint32(DMA_CONTROL_BLOCK_ADDR, CHUNKS_ADDR[0]);
      cpu.writeUint32(DMA_CONTROL_BLOCK_ADDR + 4, CHUNKS_ADDR[1]);
      cpu.writeUint32(DMA_CONTROL_BLOCK_ADDR + 8, CHUNKS_ADDR[2]);
      cpu.writeUint32(DMA_CONTROL_BLOCK_ADDR + 12, CHUNKS_ADDR[3]);
      cpu.writeUint32(
        DMA_CONTROL_BLOCK_ADDR + 16,
        0,
      ); // This marks the end of the chain

      // Channel 2 is used to copy the 8-byte chunks. Configure it:
      cpu.writeUint32(CH2_WRITE_ADDR, DEST_ADDR);
      cpu.writeUint32(
        CH2_TRANS_COUNT,
        2,
      ); // 2 transfers of 4 bytes each = 8 bytes
      cpu.writeUint32(
        CH2_AL1_CTRL,
        EN |
            (6 << CHAIN_TO_SHIFT) |
            INCR_WRITE |
            INCR_READ |
            (TREQ_PERMANENT << TREQ_SEL_SHIFT) |
            (2 << DATA_SIZE_SHIFT),
      );

      // Channel 6 is used to control channel 2:
      cpu.writeUint32(CH6_WRITE_ADDR, CH2_AL3_READ_ADDR_TRIG);
      cpu.writeUint32(CH6_READ_ADDR, DMA_CONTROL_BLOCK_ADDR);
      cpu.writeUint32(CH6_TRANS_COUNT, 1); // we'll copy one word at a time
      cpu.writeUint32(
        CH6_CTRL_TRIG,
        EN |
            INCR_READ |
            (TREQ_PERMANENT << TREQ_SEL_SHIFT) |
            (2 << DATA_SIZE_SHIFT),
      );

      expect(cpu.readUint32(CH6_CTRL_TRIG) & BUSY, BUSY);

      // Now the DMA transfer should be running. Skip some clock cycles, allowing it to finish:
      clock.advance(32);

      // Check that the transfer has indeed completed
      expect(cpu.readUint32(CH2_AL3_READ_ADDR_TRIG), 0);
      expect(cpu.readUint32(CH2_AL1_CTRL) & BUSY, 0);
      expect(cpu.readUint32(CH6_CTRL_TRIG) & BUSY, 0);
      expect(cpu.readUint32(INTR), bit(2) | bit(6));

      // Assert that the data was copied correctly:
      expect(cpu.readUint16(DEST_ADDR + 0), 0x10);
      expect(cpu.readUint16(DEST_ADDR + 4), 0x20);
      expect(cpu.readUint16(DEST_ADDR + 8), 0x30);
      expect(cpu.readUint16(DEST_ADDR + 12), 0x40);
      expect(cpu.readUint16(DEST_ADDR + 16), 0x50);
      expect(cpu.readUint16(DEST_ADDR + 20), 0x60);
      expect(cpu.readUint16(DEST_ADDR + 24), 0x70);
      expect(cpu.readUint16(DEST_ADDR + 28), 0x80);
      expect(cpu.readUint16(DEST_ADDR + 32), 0x0);
    });

    test(
      'should not dispatch the offset just past the channel registers to a non-existent channel',
      () {
        final clock = MockClock();
        final cpu = RP2040(clock);

        // Offset 0x300 is the first address after the 12 channel register blocks.
        // It must not be routed to channel index 12 (0x300 >> 6), which does not exist.
        expect(() => cpu.readUint32(PAST_CHANNELS), returnsNormally);
        expect(() => cpu.writeUint32(PAST_CHANNELS, 0x1234), returnsNormally);
      },
    );
  });
}
