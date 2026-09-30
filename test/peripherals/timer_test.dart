// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/clock/mock_clock.dart';
import 'package:rp2040_dart/src/rp2040.dart';
import 'package:test/test.dart';

const ALARM1 = 0x40054014;
const ALARM2 = 0x40054018;
const ALARM3 = 0x4005401c;
const ARMED = 0x40054020;
const INTR = 0x40054034;
const INTR_CLEAR = INTR | 0x3000;
const INTE = 0x40054038;
const INTF = 0x4005403c;
const INTS = 0x40054040;

void main() {
  group('RPTimer', () {
    group('Alarms', () {
      test('should set Alarm 1 to armed when writing to ALARM1 register', () {
        final rp2040 = RP2040(MockClock());
        rp2040.writeUint32(ALARM1, 0x1000);
        expect(rp2040.readUint32(ARMED), 0x2);
      });

      test('should disarm Alarm 2 when writing 0x4 to the ARMED register', () {
        final rp2040 = RP2040();
        rp2040.writeUint32(ALARM2, 0x1000);
        expect(rp2040.readUint32(ARMED), 0x4);
        rp2040.writeUint32(ARMED, 0xff);
        expect(rp2040.readUint32(ARMED), 0);
      });

      test('should generate an IRQ 3 interrupt when Alarm 3 fires', () {
        final clock = MockClock();
        final rp2040 = RP2040(clock);
        // Arm the alarm
        rp2040.writeUint32(ALARM3, 1000);
        expect(rp2040.readUint32(ARMED), 0x8);
        expect(rp2040.readUint32(INTR), 0);
        // Advance time so that the alarm will fire
        clock.advance(2000);
        expect(rp2040.readUint32(ARMED), 0);
        expect(rp2040.readUint32(INTR), 0x8);
        expect(rp2040.readUint32(INTS), 0);
        expect(rp2040.core.pendingInterrupts, 0);
        // Enable the interrupts for all alarms
        rp2040.writeUint32(INTE, 0xff);
        expect(rp2040.readUint32(INTS), 0x8);
        expect(rp2040.core.pendingInterrupts, 0x8);
        expect(rp2040.core.interruptsUpdated, true);
        // Clear the alarm's interrupt
        rp2040.writeUint32(INTR_CLEAR, 0x8);
        expect(rp2040.readUint32(INTS), 0);
        expect(rp2040.core.pendingInterrupts, 0);
      });

      test(
        'should generate an interrupt if INTF is 1 even when the INTE bit is 0',
        () {
          final clock = MockClock();
          final rp2040 = RP2040(clock);
          expect(rp2040.readUint32(INTS), 0);
          expect(rp2040.readUint32(INTE), 0);
          rp2040.writeUint32(INTF, 0x4);
          // The corresponding interrupt bit should be 1
          expect(rp2040.readUint32(INTS), 0x4);
        },
      );
    });
  });
}
