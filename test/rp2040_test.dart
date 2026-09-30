// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:typed_data';

import 'package:rp2040_dart/src/peripherals/peripheral.dart';
import 'package:rp2040_dart/src/rp2040.dart';
import 'package:rp2040_dart/src/utils/assembler.dart';
import 'package:rp2040_dart/src/utils/bit.dart';
import 'package:test/test.dart';

const r0 = 0;
const r4 = 4;
const lr = 14;

const VTOR = 0xe000ed08;
const NVIC_ISER = 0xe000e100;
const NVIC_ICER = 0xe000e180;
const NVIC_ISPR = 0xe000e200;
const NVIC_ICPR = 0xe000e280;

/// Stands in for `vi.spyOn(testPeripheral, ...)`: records `writeUint32` calls
/// and passes them on, and optionally mocks `readUint32`'s return value.
class _SpyPeripheral extends BasePeripheral {
  final List<(int, int)> writeUint32Calls = [];
  int? readUint32ReturnValue;

  _SpyPeripheral(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    final mocked = readUint32ReturnValue;
    return mocked ?? super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    writeUint32Calls.add((offset, value));
    super.writeUint32(offset, value);
  }
}

void main() {
  group('RP2040', () {
    test("should initialize PC and SP according to bootrom's vector table", () {
      final rp2040 = RP2040();
      rp2040.loadBootrom(Uint32List.fromList([0x20041f00, 0xee]));
      expect(rp2040.core.SP, 0x20041f00);
      expect(rp2040.core.PC, 0xee);
    });

    group('IO Register Writes', () {
      test('should replicate 8-bit values four times', () {
        final rp2040 = RP2040();
        final testPeripheral = _SpyPeripheral(rp2040, 'TestPeripheral');
        rp2040.peripherals[0x10] = testPeripheral;
        rp2040.writeUint8(0x10123, 0x534);
        expect(testPeripheral.writeUint32Calls, contains((0x120, 0x34343434)));
      });

      test('should replicate 16-bit values twice', () {
        final rp2040 = RP2040();
        final testPeripheral = _SpyPeripheral(rp2040, 'TestPeripheral');
        rp2040.peripherals[0x10] = testPeripheral;
        rp2040.writeUint16(0x10123, 0x12345678);
        expect(testPeripheral.writeUint32Calls, contains((0x120, 0x56785678)));
      });

      test('should support atomic I/O register write addresses', () {
        final rp2040 = RP2040();
        final testPeripheral = _SpyPeripheral(rp2040, 'TestAtomic');
        testPeripheral.readUint32ReturnValue = 0xff;
        rp2040.peripherals[0x10] = testPeripheral;
        rp2040.writeUint32(0x11120, 0x0f);
        expect(testPeripheral.writeUint32Calls, contains((0x120, 0xf0)));
      });
    });

    group('exceptionEntry and exceptionReturn', () {
      test(
        'should execute an exception handler and return from it correctly',
        () {
          const INT1 = 1 << 1;
          const INT1_HANDLER = 0x10000100;
          const EXC_INT1 = 16 + 1;
          final rp2040 = RP2040();
          rp2040.core.SP = 0x20004000;
          rp2040.core.PC = 0x10004001;
          rp2040.core.registers[r0] = 0x44;
          rp2040.core.pendingInterrupts = INT1;
          rp2040.core.enabledInterrupts = INT1;
          rp2040.core.interruptsUpdated = true;
          rp2040.writeUint32(VTOR, 0x10000000);
          rp2040.writeUint32(0x10000000 + EXC_INT1 * 4, INT1_HANDLER);
          rp2040.writeUint16(INT1_HANDLER, opcodeMOVS(r0, 0x55));
          rp2040.writeUint16(INT1_HANDLER + 2, opcodeBX(lr));
          // Exception handler should start at this point.
          rp2040.step(); // MOVS r0, 0x55
          expect(rp2040.core.IPSR, EXC_INT1);
          expect(rp2040.core.PC, INT1_HANDLER + 2);
          expect(rp2040.core.registers[r0], 0x55);
          rp2040.step(); // BX lr
          // Exception handler should return at this point.
          expect(rp2040.core.PC, 0x10004000);
          expect(rp2040.core.registers[r0], 0x44);
          expect(rp2040.core.IPSR, 0);
        },
      );

      test('should return correctly from exception with POP {lr}', () {
        const INT1 = 1 << 1;
        const INT1_HANDLER = 0x10000100;
        const EXC_INT1 = 16 + 1;
        final rp2040 = RP2040();
        rp2040.core.SP = 0x20004000;
        rp2040.core.PC = 0x10004001;
        rp2040.core.registers[r4] = 105;
        rp2040.core.pendingInterrupts = INT1;
        rp2040.core.enabledInterrupts = INT1;
        rp2040.core.interruptsUpdated = true;
        rp2040.writeUint32(VTOR, 0x10000000);
        rp2040.writeUint32(0x10000000 + EXC_INT1 * 4, INT1_HANDLER);
        rp2040.writeUint16(INT1_HANDLER, opcodePUSH(true, 112)); // 0b01110000
        rp2040.writeUint16(INT1_HANDLER + 2, opcodeMOVS(r4, 42));
        rp2040.writeUint16(
          INT1_HANDLER + 4,
          opcodePOP(true, 112),
        ); // 0b01110000
        // Exception handler should start at this point.
        rp2040.step(); // push {r4, r5, r6, lr}
        expect(rp2040.core.IPSR, EXC_INT1);
        expect(rp2040.core.PC, INT1_HANDLER + 2);
        rp2040.step(); // mov r4, 42
        expect(rp2040.core.registers[r4], 42);
        rp2040.step(); // pop {r4, r5, r6, pc}
        // Exception handler should return at this point.
        expect(rp2040.core.PC, 0x10004000);
        expect(rp2040.core.registers[r4], 105);
        expect(rp2040.core.IPSR, 0);
      });

      test(
        'should clear the pending interrupt flag in exceptionEntry() for user IRQs (> 25)',
        () {
          // rp2040js's `1 << 31` is negative; here it is the unsigned 0x80000000
          final INT31 = u32(1 << 31);
          const INT31_HANDLER = 0x10003100;
          const EXC_INT31 = 16 + 31;
          final rp2040 = RP2040();
          rp2040.core.SP = 0x20004000;
          rp2040.core.PC = 0x10004001;
          rp2040.writeUint32(NVIC_ISPR, INT31); // Set IRQ31 to pending
          rp2040.core.enabledInterrupts = INT31;
          rp2040.core.interruptsUpdated = true;
          rp2040.writeUint32(VTOR, 0x10000000);
          rp2040.writeUint32(0x10000000 + EXC_INT31 * 4, INT31_HANDLER);
          rp2040.writeUint16(INT31_HANDLER, opcodeNOP());
          expect(rp2040.core.pendingInterrupts, INT31);
          // Exception handler should start at this point.
          rp2040.step(); // nop
          expect(
            rp2040.core.pendingInterrupts,
            0,
          ); // interrupt flag has been cleared
          expect(rp2040.readUint32(NVIC_ISPR), 0);
        },
      );
    });

    group('NVIC registers', () {
      test(
        'writing to NVIC_ISPR should set the corresponding pending interrupt bits',
        () {
          final rp2040 = RP2040();
          rp2040.core.pendingInterrupts = 0x1;
          rp2040.writeUint32(NVIC_ISPR, 0x10);
          expect(rp2040.core.pendingInterrupts, 0x11);
        },
      );

      test(
        'writing to NVIC_ICPR should clear corresponding pending interrupt bits',
        () {
          final rp2040 = RP2040();
          rp2040.core.pendingInterrupts = 0xff00000f;
          rp2040.writeUint32(NVIC_ICPR, 0x1000000f);
          // Only the high 6 bits are actually cleared (see commit 5bc96994 for details)
          expect(rp2040.readUint32(NVIC_ISPR), 0xef00000f);
        },
      );

      test(
        'writing to NVIC_ISER should set the corresponding enabled interrupt bits',
        () {
          final rp2040 = RP2040();
          rp2040.core.enabledInterrupts = 0x1;
          rp2040.writeUint32(NVIC_ISER, 0x10);
          expect(rp2040.core.enabledInterrupts, 0x11);
        },
      );

      test(
        'writing to NVIC_ICER should clear corresponding enabled interrupt bits',
        () {
          final rp2040 = RP2040();
          rp2040.core.enabledInterrupts = 0xff;
          rp2040.writeUint32(NVIC_ICER, 0x10);
          expect(rp2040.core.enabledInterrupts, 0xef);
        },
      );

      test(
        'reading from NVIC_ISER/NVIC_ICER should return the current enabled interrupt bits',
        () {
          final rp2040 = RP2040();
          rp2040.core.enabledInterrupts = 0x1;
          expect(rp2040.readUint32(NVIC_ISER), 0x1);
          expect(rp2040.readUint32(NVIC_ICER), 0x1);
        },
      );

      test(
        'reading from NVIC_ISPR/NVIC_ICPR should return the current enabled interrupt bits',
        () {
          final rp2040 = RP2040();
          rp2040.core.pendingInterrupts = 0x2;
          expect(rp2040.readUint32(NVIC_ISPR), 0x2);
          expect(rp2040.readUint32(NVIC_ICPR), 0x2);
        },
      );

      test(
        'should update the interrupt levels correctly when writing to NVIC_IPR3',
        () {
          final rp2040 = RP2040();
          // Set the priority of interrupt number 14 to 2
          rp2040.writeUint32(0xe000e40c, 0x00800000);
          final interruptPriorities = rp2040.core.interruptPriorities;
          expect(s32(interruptPriorities[0]), s32(~(1 << 14)));
          expect(interruptPriorities[1], 0);
          expect(interruptPriorities[2], 1 << 14);
          expect(interruptPriorities[3], 0);
          expect(rp2040.readUint32(0xe000e40c), 0x00800000);
        },
      );

      test(
        'should return the correct interrupt priorities when reading from NVIC_IPR5',
        () {
          final rp2040 = RP2040();
          rp2040.core.interruptPriorities[0] = 0;
          rp2040.core.interruptPriorities[1] =
              0x001fffff; // interrupts 0 ... 20
          rp2040.core.interruptPriorities[2] = 0x00200000; // interrupt 21
          rp2040.core.interruptPriorities[3] =
              0xffc00000; // interrupt 22 ... 31
          // Set the priority of interrupt number 14 to 2
          // (rp2040js compares with `0xc0c08040 | 0`; reads are unsigned here)
          expect(rp2040.readUint32(0xe000e414), 0xc0c08040);
        },
      );
    });
  });
}
