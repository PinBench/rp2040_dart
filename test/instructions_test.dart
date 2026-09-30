// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/rp2040.dart';
import 'package:rp2040_dart/src/utils/assembler.dart';
import 'package:rp2040_dart/src/utils/bit.dart';
import 'package:test/test.dart';

import 'test_utils/create_test_driver.dart';
import 'test_utils/test_driver.dart';
import 'test_utils/test_driver_rp2040.dart';

const int r0 = 0;
const int r1 = 1;
const int r2 = 2;
const int r3 = 3;
const int r4 = 4;
const int r5 = 5;
const int r6 = 6;
const int r7 = 7;
const int r8 = 8;
const int r11 = 11;
const int r12 = 12;
const int ip = 12;
const int sp = 13;
const int lr = 14;
const int pc = 15;

const int VTOR = 0xe000ed08;
const int EXC_SVCALL = 11;

/// Stands in for vitest's `vi.fn()`: records the argument of every call.
class _BreakMock {
  final List<int> calls = [];

  void call(int code) {
    calls.add(code);
  }
}

void main() {
  group('Cortex-M0+ Instruction Set', () {
    late ICortexTestDriver cpu;

    setUp(() {
      cpu = createTestDriver();
    });

    tearDown(() {
      cpu.tearDown();
    });

    test('should execute `adcs r5, r4` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeADCS(r5, r4));
      cpu.setRegisters(r4: 55, r5: 66, C: true);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 122);
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, false);
      expect(registers.V, false);
    });

    test(
      'should execute `adcs r5, r4` instruction and set negative/overflow flags',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeADCS(r5, r4));
        cpu.setRegisters(
          r4: 0x7fffffff, // Max signed INT32
          r5: 0,
          C: true,
        );
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r5, 0x80000000);
        expect(registers.N, true);
        expect(registers.Z, false);
        expect(registers.C, false);
        expect(registers.V, true);
      },
    );

    test(
      'should not set the overflow flag when executing `adcs r3, r2` adding 0 to 0 with carry',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeADCS(r3, r2));
        cpu.setRegisters(r2: 0, r3: 0, C: true, Z: true);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r3, 1);
        expect(registers.N, false);
        expect(registers.Z, false);
        expect(registers.C, false);
        expect(registers.V, false);
      },
    );

    test(
      'should set the zero, carry and overflow flag when executing `adcs r0, r0` adding 0x80000000 to 0x80000000',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeADCS(r0, r0));
        cpu.setRegisters(r0: 0x80000000, C: false);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r0, 0);
        expect(registers.N, false);
        expect(registers.Z, true);
        expect(registers.C, true);
        expect(registers.V, true);
      },
    );

    test('should execute a `add sp, 0x10` instruction', () {
      cpu.setPC(0x20000000);
      cpu.setRegisters(sp: 0x10000040);
      cpu.writeUint16(0x20000000, opcodeADDsp2(0x10));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.sp, 0x10000050);
    });

    test('should execute a `add r1, sp, #4` instruction', () {
      cpu.setPC(0x20000000);
      cpu.setRegisters(sp: 0x54);
      cpu.writeUint16(0x20000000, opcodeADDspPlusImm(r1, 0x10));
      cpu.setRegisters(r1: 0);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.sp, 0x54);
      expect(registers.r1, 0x64);
    });

    test('should execute `adds r1, r2, #3` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeADDS1(r1, r2, 3));
      cpu.setRegisters(r2: 2);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 5);
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, false);
      expect(registers.V, false);
    });

    test('should execute `adds r1, #1` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeADDS2(r1, 1));
      cpu.setRegisters(r1: 0xffffffff);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 0);
      expect(registers.N, false);
      expect(registers.Z, true);
      expect(registers.C, true);
      expect(registers.V, false);
    });

    test('should execute `adds r1, r2, r7` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeADDSreg(r1, r2, r7));
      cpu.setRegisters(r2: 2);
      cpu.setRegisters(r7: 27);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 29);
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, false);
      expect(registers.V, false);
    });

    test('should execute `adds r4, r4, r2` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeADDSreg(r4, r4, r2));
      cpu.setRegisters(r2: 0x74bc8000, r4: 0x43740000);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r4, 0xb8308000);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, false);
      expect(registers.V, true);
    });

    test('should execute `adds r1, r1, r1` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeADDSreg(r1, r1, r1));
      cpu.setRegisters(r1: 0xbf8d1424, C: true);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 0x7f1a2848);
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, true);
      expect(registers.V, true);
    });

    test('should execute `add r1, ip` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeADDreg(r1, ip));
      cpu.setRegisters(r1: 66, r12: 44);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 110);
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, false);
      expect(registers.V, false);
    });

    test(
      'should not update the flags following `add r3, r12` instruction (encoding T2)',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeADDreg(r3, r12));
        cpu.setRegisters(r3: 0x00002000, r12: 0xffffe000);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r3, 0);
        expect(registers.N, false);
        expect(registers.Z, false);
        expect(registers.C, false);
        expect(registers.V, false);
      },
    );

    test(
      'should execute `add sp, r8` instruction and not update the flags',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeADDreg(sp, r8));
        cpu.setRegisters(sp: 0x20030000, Z: true, r8: 0x13);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.sp, 0x20030010);
        expect(registers.Z, true); // assert it didn't update the flags
      },
    );

    test('should execute `add pc, r8` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeADDreg(pc, r8));
      cpu.setRegisters(r8: 0x11);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000014);
    });

    test(
      'should execute `add r7, pc` instruction with correct PC+4 value (word-aligned)',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeADDreg(r7, pc));
        cpu.setRegisters(r7: 0);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        // PC value used by ADD should be instruction address + 4
        expect(registers.r7, 0x20000004);
      },
    );

    test(
      'should execute `add r7, pc` instruction with correct PC+4 value (half-word-aligned)',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeNOP());
        cpu.writeUint16(0x20000002, opcodeADDreg(r7, pc));
        cpu.setRegisters(r7: 0);
        cpu.singleStep();
        cpu.singleStep();
        final registers = cpu.readRegisters();
        // PC value used by ADD should be instruction address + 4 (no word-alignment)
        expect(registers.r7, 0x20000006);
      },
    );

    test(
      'should execute `adr r4, #0x50` instruction and set the overflow flag correctly',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeADR(r4, 0x50));
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r4, 0x20000054);
      },
    );

    test('should execute `ands r5, r0` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeANDS(r5, r0));
      cpu.setRegisters(r5: 0xffff0000);
      cpu.setRegisters(r0: 0xf00fffff);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 0xf00f0000);
      expect(registers.N, true);
      expect(registers.Z, false);
    });

    test('should execute an `asrs r3, r2, #31` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeASRS(r3, r2, 31));
      cpu.setRegisters(r2: 0x80000000, C: true);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0xffffffff);
      expect(registers.pc, 0x20000002);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, false);
    });

    test(
      'should correctly update the carry flags when executing `asrs r3, r2, #32` instruction',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeASRS(r3, r2, 0));
        cpu.setRegisters(r2: 0x80000000, C: false);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r3, 0xffffffff);
        expect(registers.pc, 0x20000002);
        expect(registers.N, true);
        expect(registers.Z, false);
        expect(registers.C, true);
      },
    );

    test('should execute an `asrs r3, r4` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeASRSreg(r3, r4));
      cpu.setRegisters(r3: 0x80000040);
      cpu.setRegisters(r4: 0xff500007);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0xff000000);
      expect(registers.pc, 0x20000002);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, true);
    });

    test('should execute an `asrs r3, r4` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeASRSreg(r3, r4));
      cpu.setRegisters(r3: 0x40000040, r4: 50, C: true);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0);
      expect(registers.pc, 0x20000002);
      expect(registers.N, false);
      expect(registers.Z, true);
      expect(registers.C, false);
    });

    test('should execute an `asrs r3, r4` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeASRSreg(r3, r4));
      cpu.setRegisters(r3: 0x40000040, r4: 31, C: true);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0);
      expect(registers.pc, 0x20000002);
      expect(registers.N, false);
      expect(registers.Z, true);
      expect(registers.C, true);
    });

    test('should execute an `asrs r3, r4` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeASRSreg(r3, r4));
      cpu.setRegisters(r3: 0x80000040, r4: 50, C: true);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0xffffffff);
      expect(registers.pc, 0x20000002);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, true);
    });

    test('should execute an `asrs r3, r4` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeASRSreg(r3, r4));
      cpu.setRegisters(r3: 0x80000040, r4: 0, C: true);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x80000040);
      expect(registers.pc, 0x20000002);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, true);
    });

    test('should execute `bics r0, r3` correctly', () {
      cpu.setPC(0x20000000);
      cpu.setRegisters(r0: 0xff);
      cpu.setRegisters(r3: 0x0f);
      cpu.writeUint16(0x20000000, opcodeBICS(r0, r3));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r0, 0xf0);
      expect(registers.N, false);
      expect(registers.Z, false);
    });

    test(
      'should execute `bics r0, r3` instruction and set the negative flag correctly',
      () {
        cpu.setPC(0x20000000);
        cpu.setRegisters(r0: 0xffffffff);
        cpu.setRegisters(r3: 0x0000ffff);
        cpu.writeUint16(0x20000000, opcodeBICS(r0, r3));
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r0, 0xffff0000);
        expect(registers.N, true);
        expect(registers.Z, false);
      },
    );

    test('should execute `bl 0x34` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint32(0x20000000, opcodeBL(0x34));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000038);
      expect(registers.lr, 0x20000005);
    });

    test('should execute `bl -0x10` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint32(0x20000000, opcodeBL(-0x10));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000004 - 0x10);
      expect(registers.lr, 0x20000005);
    });

    test('should execute `bl -3242` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint32(0x20000000, opcodeBL(-3242));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000004 - 3242);
      expect(registers.lr, 0x20000005);
    });

    test('should execute `blx r3` instruction', () {
      cpu.setPC(0x20000000);
      cpu.setRegisters(r3: 0x20000201);
      cpu.writeUint32(0x20000000, opcodeBLX(r3));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000200);
      expect(registers.lr, 0x20000003);
    });

    test('should execute a `b.n .-20` instruction', () {
      cpu.setPC(0x20000000 + 9 * 2);
      cpu.writeUint16(0x20000000 + 9 * 2, opcodeBT2(0xfec));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000002);
    });

    test('should execute a `bne.n .-6` instruction', () {
      cpu.setPC(0x20000000 + 9 * 2);
      cpu.setRegisters(Z: false);
      cpu.writeUint16(0x20000000 + 9 * 2, opcodeBT1(1, 0x1f8));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x2000000e);
    });

    test('should execute `bx lr` instruction', () {
      cpu.setPC(0x20000000);
      cpu.setRegisters(lr: 0x10000200);
      cpu.writeUint32(0x20000000, opcodeBX(lr));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x10000200);
    });

    test('should execute an `cmn r5, r2` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeCMN(r7, r2));
      cpu.setRegisters(r2: 1);
      cpu.setRegisters(r7: -2);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r2, 1);
      expect(registers.r7, u32(-2));
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, false);
      expect(registers.V, false);
    });

    test('should execute an `cmp r5, #66` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeCMPimm(r5, 66));
      cpu.setRegisters(r5: 60);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, false);
      expect(registers.V, false);
    });

    test('should correctly set carry flag when executing `cmp r0, #0`', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeCMPimm(r0, 0));
      cpu.setRegisters(r0: 0x80010133);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, true);
      expect(registers.V, false);
    });

    test('should execute an `cmp r5, r0` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeCMPregT1(r5, r0));
      cpu.setRegisters(r5: 60);
      cpu.setRegisters(r0: 56);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, true);
      expect(registers.V, false);
    });

    test(
      'should execute an `cmp r2, r0` instruction and not set any flags when r0=0xb71b0000 and r2=0x00b71b00',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeCMPregT1(r2, r0));
        cpu.setRegisters(r0: 0xb71b0000, r2: 0x00b71b00);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.N, false);
        expect(registers.Z, false);
        expect(registers.C, false);
        expect(registers.V, false);
      },
    );

    test(
      'should correctly set carry flag when executing `cmp r11, r3` instruction',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeCMPregT2(r11, r3));
        cpu.setRegisters(r3: 0x00000008, r11: 0xffffffff);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.N, true);
        expect(registers.Z, false);
        expect(registers.C, true);
        expect(registers.V, false);
      },
    );

    test('should execute an `cmp ip, r6` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeCMPregT2(ip, r6));
      cpu.setRegisters(r6: 56, r12: 60);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, true);
      expect(registers.V, false);
    });

    test(
      'should set flags N C when executing `cmp r11, r3` instruction when r3=0 and r11=0x80000000',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeCMPregT2(r11, r3));
        cpu.setRegisters(r3: 0, r11: 0x80000000);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.N, true);
        expect(registers.Z, false);
        expect(registers.C, true);
        expect(registers.V, false);
      },
    );

    test(
      'should set flags N V when executing `cmp r3, r7` instruction when r3=0 and r7=0x80000000',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeCMPregT1(r3, r7));
        cpu.setRegisters(r3: 0, r7: 0x80000000);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.N, true);
        expect(registers.Z, false);
        expect(registers.C, false);
        expect(registers.V, true);
      },
    );

    test(
      'should set flags N V when executing `cmp r11, r3` instruction when r3=0x80000000 and r11=0',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeCMPregT2(r11, r3));
        cpu.setRegisters(r3: 0x80000000, r11: 0);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.N, true);
        expect(registers.Z, false);
        expect(registers.C, false);
        expect(registers.V, true);
      },
    );

    test(
      'should set flags N C when executing `cmp r3, r7` instruction when r3=0x80000000 and r7=0',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeCMPregT1(r3, r7));
        cpu.setRegisters(r3: 0x80000000, r7: 0);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.N, true);
        expect(registers.Z, false);
        expect(registers.C, true);
        expect(registers.V, false);
      },
    );

    test('should correctly decode a `dmb sy` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint32(0x20000000, opcodeDMBSY());
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000004);
    });

    test('should correctly decode a `dsb sy` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint32(0x20000000, opcodeDSBSY());
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000004);
    });

    test('should execute an `eors r1, r3` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeEORS(r1, r3));
      cpu.setRegisters(r1: 0xf0f0f0f0);
      cpu.setRegisters(r3: 0x08ff3007);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 0xf80fc0f7);
      expect(registers.N, true);
      expect(registers.Z, false);
    });

    test('should correctly decode a `isb sy` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint32(0x20000000, opcodeISBSY());
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000004);
    });

    test('should execute a `mov r3, r8` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeMOV(r3, r8));
      cpu.setRegisters(r8: 55);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 55);
    });

    test('should execute a `mov r3, pc` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeMOV(r3, pc));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x20000004);
    });

    test('should execute a `mov sp, r8` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeMOV(r3, r8));
      cpu.setRegisters(r8: 55);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 55);
    });

    test('should execute a `muls r0, r2` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeMULS(r0, r2));
      cpu.setRegisters(r0: 5);
      cpu.setRegisters(r2: 1000000);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r2, 5000000);
      expect(registers.N, false);
      expect(registers.Z, false);
    });

    test(
      'should execute a muls instruction with large 32-bit numbers and produce the correct result',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeMULS(r0, r2));
        cpu.setRegisters(r0: 2654435769);
        cpu.setRegisters(r2: 340573321);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r2, 1);
      },
    );

    test(
      'should execute a `muls r0, r2` instruction and set the Z flag when the result is zero',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeMULS(r0, r2));
        cpu.setRegisters(r0: 0);
        cpu.setRegisters(r2: 1000000);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r2, 0);
        expect(registers.N, false);
        expect(registers.Z, true);
      },
    );

    test(
      'should execute a `muls r0, r2` instruction and set the N flag when the result is negative',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeMULS(r0, r2));
        cpu.setRegisters(r0: -1);
        cpu.setRegisters(r2: 1000000);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r2, u32(-1000000));
        expect(registers.N, true);
        expect(registers.Z, false);
      },
    );

    test('should execute a `mvns r4, r3` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeMVNS(r4, r3));
      cpu.setRegisters(r3: 0x11115555);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r4, 0xeeeeaaaa);
      expect(registers.Z, false);
      expect(registers.N, true);
    });

    test('should execute a `nop` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeNOP());
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000002);
    });

    test('should execute `orrs r5, r0` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeORRS(r5, r0));
      cpu.setRegisters(r5: 0xf00f0000);
      cpu.setRegisters(r0: 0xf000ffff);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 0xf00fffff);
      expect(registers.N, true);
      expect(registers.Z, false);
    });

    test('should execute a `pop pc, {r4, r5, r6}` instruction', () {
      cpu.setPC(0x20000000);
      cpu.setRegisters(sp: RAM_START_ADDRESS + 0xf0);
      cpu.writeUint16(
        0x20000000,
        opcodePOP(true, (1 << r4) | (1 << r5) | (1 << r6)),
      );
      cpu.writeUint32(0x200000f0, 0x40);
      cpu.writeUint32(0x200000f4, 0x50);
      cpu.writeUint32(0x200000f8, 0x60);
      cpu.writeUint32(0x200000fc, 0x42);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.sp, RAM_START_ADDRESS + 0x100);
      // assert that the values of r4, r5, r6, pc were poped from the stack correctly
      expect(registers.r4, 0x40);
      expect(registers.r5, 0x50);
      expect(registers.r6, 0x60);
      expect(registers.pc, 0x42);
    });

    test('should execute a `push {r4, r5, r6, lr}` instruction', () {
      cpu.setPC(0x20000000);
      cpu.setRegisters(sp: RAM_START_ADDRESS + 0x100);
      cpu.writeUint16(
        0x20000000,
        opcodePUSH(true, (1 << r4) | (1 << r5) | (1 << r6)),
      );
      cpu.setRegisters(r4: 0x40, r5: 0x50, r6: 0x60, lr: 0x42);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      // assert that the values of r4, r5, r6, lr were pushed into the stack
      expect(registers.sp, RAM_START_ADDRESS + 0xf0);
      expect(cpu.readUint8(0x200000f0), 0x40);
      expect(cpu.readUint8(0x200000f4), 0x50);
      expect(cpu.readUint8(0x200000f8), 0x60);
      expect(cpu.readUint8(0x200000fc), 0x42);
    });

    test('should execute a `mrs r0, ipsr` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint32(0x20000000, opcodeMRS(r0, 5)); // 5 == ipsr
      cpu.setRegisters(r0: 55);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r0, 0);
      expect(registers.pc, 0x20000004);
    });

    test('should execute a `msr msp, r0` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint32(0x20000000, opcodeMSR(8, r0)); // 8 == msp
      cpu.setRegisters(r0: 0x1234);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.sp, 0x1234);
      expect(registers.pc, 0x20000004);
    });

    test('should execute a `movs r5, #128` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeMOVS(r5, 128));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 128);
      expect(registers.pc, 0x20000002);
    });

    test('should execute a `ldmia r0!, {r1, r2}` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDMIA(r0, (1 << r1) | (1 << r2)));
      cpu.setRegisters(r0: 0x20000010);
      cpu.writeUint32(0x20000010, 0xf00df00d);
      cpu.writeUint32(0x20000014, 0x4242);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000002);
      expect(registers.r0, 0x20000018);
      expect(registers.r1, 0xf00df00d);
      expect(registers.r2, 0x4242);
    });

    test(
      'should execute a `ldmia r5!, {r5}` instruction without writing back the address to r5',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeLDMIA(r5, 1 << r5));
        cpu.setRegisters(r5: 0x20000010);
        cpu.writeUint32(0x20000010, 0xf00df00d);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.pc, 0x20000002);
        expect(registers.r5, 0xf00df00d);
      },
    );

    test('should execute an `ldr r0, [pc, #148]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRlit(r0, 148));
      cpu.writeUint32(0x20000000 + 152, 0x42);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r0, 0x42);
      expect(registers.pc, 0x20000002);
    });

    test('should execute an `ldr r3, [r2, #24]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRimm(r3, r2, 24));
      cpu.setRegisters(r2: 0x20000000);
      cpu.writeUint32(0x20000000 + 24, 0x55);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x55);
    });

    test('should execute an `ldr r3, [sp, #12]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.setRegisters(sp: 0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRsp(r3, 12));
      cpu.writeUint32(0x20000000 + 12, 0x55);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x55);
    });

    test('should execute an `ldr r3, [r5, r6]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRreg(r3, r5, r6));
      cpu.setRegisters(r5: 0x20000000);
      cpu.setRegisters(r6: 0x8);
      cpu.writeUint32(0x20000008, 0xff554211);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0xff554211);
    });

    test('should execute an `ldrb r4, [r2, 5]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRB(r4, r2, 5));
      cpu.setRegisters(r2: 0x20000000);
      cpu.writeUint16(0x20000005, 0x7766);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r4, 0x66);
    });

    test('should execute an `ldrb r3, [r5, r6]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRBreg(r3, r5, r6));
      cpu.setRegisters(r5: 0x20000000);
      cpu.setRegisters(r6: 0x8);
      cpu.writeUint32(0x20000008, 0xff554211);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x11);
    });

    test('should execute an `ldrh r3, [r7, #4]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRH(r3, r7, 4));
      cpu.setRegisters(r7: 0x20000000);
      cpu.writeUint32(0x20000004, 0xffff7766);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x7766);
    });

    test('should execute an `ldrh r3, [r7, #6]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRH(r3, r7, 6));
      cpu.setRegisters(r7: 0x20000000);
      cpu.writeUint32(0x20000004, 0x33447766);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x3344);
    });

    test('should execute an `ldrh r3, [r5, r6]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRHreg(r3, r5, r6));
      cpu.setRegisters(r5: 0x20000000, r6: 0x8);
      cpu.writeUint32(0x20000008, 0xff554211);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x4211);
    });

    test('should execute an `ldrsb r5, [r3, r5]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRSB(r5, r3, r5));
      cpu.setRegisters(r3: 0x20000000, r5: 6);
      cpu.writeUint32(0x20000006, 0x85);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 0xffffff85);
    });

    test('should execute an `ldrsh r5, [r3, r5]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLDRSH(r5, r3, r5));
      cpu.setRegisters(r3: 0x20000000);
      cpu.setRegisters(r5: 6);
      cpu.writeUint16(0x20000006, 0xf055);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 0xfffff055);
    });

    test('should execute a `udf 1` instruction', () {
      final breakMock = _BreakMock();
      final rp2040 = RP2040();
      rp2040.core.PC = 0x20000000;
      rp2040.writeUint16(0x20000000, opcodeUDF(0x1));
      rp2040.onBreak = breakMock.call;
      rp2040.step();
      expect(rp2040.core.PC, 0x20000002);
      expect(breakMock.calls, contains(1));
    });

    test('should execute a `udf.w #0` (T2 encoding) instruction', () {
      final breakMock = _BreakMock();
      final rp2040 = RP2040();
      rp2040.core.PC = 0x20000000;
      rp2040.writeUint32(0x20000000, opcodeUDF2(0));
      rp2040.onBreak = breakMock.call;
      rp2040.step();
      expect(rp2040.core.PC, 0x20000004);
      expect(breakMock.calls, contains(0));
    });

    test('should execute a `lsls r5, r5, #18` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLSLSimm(r5, r5, 18));
      cpu.setRegisters(r5: 0x3 /* 0b00000000000000000011 */);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 0xc0000 /* 0b11000000000000000000 */);
      expect(registers.pc, 0x20000002);
      expect(registers.C, false);
    });

    test('should execute a `lsls r5, r0` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLSLSreg(r5, r0));
      cpu.setRegisters(r5: 0x3 /* 0b00000000000000000011 */);
      cpu.setRegisters(r0: 0xff003302); // bottom byte: 02
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 0xc /* 0b00000000000000001100 */);
      expect(registers.pc, 0x20000002);
      expect(registers.C, false);
    });

    test('should execute a lsls r3, r4 instruction when shift >31', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLSLSreg(r3, r4));
      cpu.setRegisters(r3: 1, r4: 0x20, C: false);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0);
      expect(registers.pc, 0x20000002);
      expect(registers.N, false);
      expect(registers.C, true);
      expect(registers.Z, true);
    });

    test('should execute a `lsls r5, r5, #18` instruction with carry', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLSLSimm(r5, r5, 18));
      cpu.setRegisters(r5: 0x00004001);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 0x40000);
      expect(registers.C, true);
    });

    test('should execute a `lsrs r5, r0` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLSRSreg(r5, r0));
      cpu.setRegisters(r5: 0xff00000f);
      cpu.setRegisters(r0: 0xff003302);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 0x3fc00003);
      expect(registers.pc, 0x20000002);
      expect(registers.C, true);
    });

    test('should return zero for `lsrs r2, r3` with 32 bit shift', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLSRSreg(r2, r3));
      cpu.setRegisters(r2: 10, r3: 32);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r2, 0);
      expect(registers.Z, true);
      expect(registers.C, false);
    });

    test('should execute a `lsrs r1, r1, #1` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLSRS(r1, r1, 1));
      cpu.setRegisters(r1: 0x2 /* 0b10 */);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 0x1 /* 0b1 */);
      expect(registers.pc, 0x20000002);
      expect(registers.C, false);
    });

    test('should execute a `lsrs r1, r1, 0` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeLSRS(r1, r1, 0));
      cpu.setRegisters(r1: 0xffffffff);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 0);
      expect(registers.pc, 0x20000002);
      expect(registers.C, true);
    });

    test(
      'should keep lower 2 bits of sp clear when executing a `movs sp, r5` instruction',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeMOV(sp, r5));
        cpu.setRegisters(r5: 0x53);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.sp, 0x50);
      },
    );

    test(
      'should keep lower bit of pc clear when executing a `movs pc, r5` instruction',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeMOV(pc, r5));
        cpu.setRegisters(r5: 0x53);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.pc, 0x52);
      },
    );

    test('should execute a `movs r6, r5` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeMOVSreg(r6, r5));
      cpu.setRegisters(r5: 0x50);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r6, 0x50);
    });

    test('should execute a `rsbs r0, r3` instruction', () {
      // This instruction is also calledasync  `negs`
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeRSBS(r0, r3));
      cpu.setRegisters(r3: 100);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(s32(registers.r0), -100);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, false);
      expect(registers.V, false);
    });

    test('should execute a `rev r3, r1` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeREV(r2, r3));
      cpu.setRegisters(r3: 0x11223344);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r2, 0x44332211);
    });

    test('should execute a `rev16 r0, r5` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeREV16(r0, r5));
      cpu.setRegisters(r5: 0x11223344);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r0, 0x22114433);
    });

    test('should execute a `revsh r1, r2` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeREVSH(r1, r2));
      cpu.setRegisters(r2: 0xeeaa55f0);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 0xfffff055);
    });

    test('should execute a `ror r5, r3` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeROR(r5, r3));
      cpu.setRegisters(r5: 0x12345678);
      cpu.setRegisters(r3: 0x2004);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x2004);
      expect(registers.r5, 0x81234567);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, true);
    });

    test('should execute a `ror r5, r3` instruction when r3 > 32', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeROR(r5, r3));
      cpu.setRegisters(r5: 0x12345678);
      cpu.setRegisters(r3: 0x2044);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x2044);
      expect(registers.r5, 0x81234567);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, true);
    });

    test('should execute a `rsbs r0, r3` instruction', () {
      // This instruction is also calledasync  `negs`
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeRSBS(r0, r3));
      cpu.setRegisters(r3: 0);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(s32(registers.r0), 0);
      expect(registers.N, false);
      expect(registers.Z, true);
      expect(registers.C, true);
      expect(registers.V, false);
    });

    test('should execute a `sbcs r0, r3` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSBCS(r0, r3));
      cpu.setRegisters(r0: 100, r3: 55, C: false);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r0, 44);
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, true);
      expect(registers.V, false);
    });

    test('should execute a `sbcs r0, r3` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSBCS(r0, r3));
      cpu.setRegisters(r0: 0, r3: 0xffffffff, C: false);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r0, 0);
      expect(registers.N, false);
      expect(registers.Z, true);
      expect(registers.C, false);
      expect(registers.V, false);
    });

    test('should execute a `sdmia r0!, {r1, r2}` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSTMIA(r0, (1 << r1) | (1 << r2)));
      cpu.setRegisters(r0: 0x20000010, r1: 0xf00df00d, r2: 0x4242);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000002);
      expect(registers.r0, 0x20000018);
      expect(cpu.readUint32(0x20000010), 0xf00df00d);
      expect(cpu.readUint32(0x20000014), 0x4242);
    });

    test('should execute a `str r6, [r4, #20]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSTR(r6, r4, 20));
      cpu.setRegisters(r4: RAM_START_ADDRESS + 0x20, r6: 0xf00d);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(cpu.readUint32(0x20000020 + 20), 0xf00d);
      expect(registers.pc, 0x20000002);
    });

    test('should execute a `str r6, [r4, r5]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSTRreg(r6, r4, r5));
      cpu.setRegisters(r4: RAM_START_ADDRESS + 0x20);
      cpu.setRegisters(r5: 20);
      cpu.setRegisters(r6: 0xf00d);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(cpu.readUint32(0x20000020 + 20), 0xf00d);
      expect(registers.pc, 0x20000002);
    });

    test('should execute an `str r3, [sp, #12]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSTRsp(r3, 12));
      cpu.setRegisters(r3: 0xaa55, sp: 0x20000000);
      cpu.singleStep();
      expect(cpu.readUint8(0x20000000 + 12), 0x55);
      expect(cpu.readUint8(0x20000000 + 13), 0xaa);
    });

    test(
      'should execute a `str r2, [r3, r1]` instruction where r1 + r3 > 32 bits',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeSTRreg(r2, r1, r3));
        cpu.setRegisters(r1: -4, r3: 0x20041e50, r2: 0x4201337);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(cpu.readUint32(0x20041e4c), 0x4201337);
        expect(registers.pc, 0x20000002);
      },
    );

    test('should execute a `strb r6, [r4, #20]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSTRB(r6, r4, 0x1));
      cpu.writeUint32(0x20000020, 0xf5f4f3f2);
      cpu.setRegisters(r4: RAM_START_ADDRESS + 0x20, r6: 0xf055);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      // assert that the 2nd byte (at 0x21) changed to 0x55
      expect(cpu.readUint32(0x20000020), 0xf5f455f2);
      expect(registers.pc, 0x20000002);
    });

    test('should execute a `strb r6, [r4, r5]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSTRBreg(r6, r4, r5));
      cpu.writeUint32(0x20000020, 0xf5f4f3f2);
      cpu.setRegisters(r4: RAM_START_ADDRESS + 0x20);
      cpu.setRegisters(r5: 1);
      cpu.setRegisters(r6: 0xf055);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      // assert that the 2nd byte (at 0x21) changed to 0x55
      expect(cpu.readUint32(0x20000020), 0xf5f455f2);
      expect(registers.pc, 0x20000002);
    });

    test('should execute a `strh r6, [r4, #20]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSTRH(r6, r4, 0x2));
      cpu.writeUint32(0x20000020, 0xf5f4f3f2);
      cpu.setRegisters(r4: RAM_START_ADDRESS + 0x20);
      cpu.setRegisters(r6: 0x6655);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      // assert that the 3rd/4th byte (at 0x22) changed to 0x6655
      expect(cpu.readUint32(0x20000020), 0x6655f3f2);
      expect(registers.pc, 0x20000002);
    });

    test('should execute a `strh r6, [r4, r1]` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSTRHreg(r6, r4, r1));
      cpu.writeUint32(0x20000020, 0xf5f4f3f2);
      cpu.setRegisters(r4: RAM_START_ADDRESS + 0x20);
      cpu.setRegisters(r1: 2);
      cpu.setRegisters(r6: 0x6655);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      // assert that the 3rd/4th byte (at 0x22) changed to 0x6655
      expect(cpu.readUint32(0x20000020), 0x6655f3f2);
      expect(registers.pc, 0x20000002);
    });

    test('should execute a `sub sp, 0x10` instruction', () {
      cpu.setPC(0x20000000);
      cpu.setRegisters(sp: 0x10000040);
      cpu.writeUint16(0x20000000, opcodeSUBsp(0x10));
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.sp, 0x10000030);
    });

    test('should execute a `subs r1, #1` instruction with overflow', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSUBS2(r1, 1));
      cpu.setRegisters(r1: -0x80000000);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r1, 0x7fffffff);
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, true);
      expect(registers.V, true);
    });

    test('should execute a `subs r5, r3, 5` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSUBS1(r5, r3, 5));
      cpu.setRegisters(r3: 0);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(s32(registers.r5), -5);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, false);
      expect(registers.V, false);
    });

    test('should execute a `subs r5, r3, r2` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSUBSreg(r5, r3, r2));
      cpu.setRegisters(r3: 6);
      cpu.setRegisters(r2: 5);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 1);
      expect(registers.N, false);
      expect(registers.Z, false);
      expect(registers.C, true);
      expect(registers.V, false);
    });

    test('should execute a `subs r3, r3, r2` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSUBSreg(r3, r3, r2));
      cpu.setRegisters(r2: 8, r3: 0xffffffff);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0xfffffff7);
      expect(registers.N, true);
      expect(registers.Z, false);
      expect(registers.C, true);
      expect(registers.V, false);
    });

    test(
      'should execute a `subs r5, r3, r2` instruction and set N V flags',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeSUBSreg(r5, r3, r2));
        cpu.setRegisters(r3: 0);
        cpu.setRegisters(r2: 0x80000000);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r5, 0x80000000);
        expect(registers.N, true);
        expect(registers.Z, false);
        expect(registers.C, false);
        expect(registers.V, true);
      },
    );

    test(
      'should execute a `subs r5, r3, r2` instruction  and set Z C flags',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeSUBSreg(r5, r3, r2));
        cpu.setRegisters(r2: 0x80000000);
        cpu.setRegisters(r3: 0x80000000);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.r5, 0);
        expect(registers.N, false);
        expect(registers.Z, true);
        expect(registers.C, true);
        expect(registers.V, false);
      },
    );

    test('should raise an SVCALL exception when `svc` instruction runs', () {
      final SVCALL_HANDLER = 0x20002000;
      cpu.setRegisters(sp: 0x20004000);
      cpu.setPC(0x20004000);
      cpu.writeUint16(0x20004000, opcodeSVC(10));
      cpu.setRegisters(r0: 0x44);
      cpu.writeUint32(VTOR, 0x20040000);
      cpu.writeUint32(0x20040000 + EXC_SVCALL * 4, SVCALL_HANDLER);
      cpu.writeUint16(SVCALL_HANDLER, opcodeMOVS(r0, 0x55));

      cpu.singleStep();
      final driver = cpu;
      if (driver is RP2040TestDriver) {
        expect(driver.rp2040.core.pendingSVCall, true);
      }

      cpu.singleStep(); // SVCall handler should run here
      final registers2 = cpu.readRegisters();
      if (driver is RP2040TestDriver) {
        expect(driver.rp2040.core.pendingSVCall, false);
      }
      expect(registers2.pc, SVCALL_HANDLER + 2);
      expect(registers2.r0, 0x55);
    });

    test('should execute a `sxtb r2, r2` instruction with sign bit 1', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSXTB(r2, r2));
      cpu.setRegisters(r2: 0x22446688);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r2, 0xffffff88);
    });

    test('should execute a `sxtb r2, r2` instruction with sign bit 0', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSXTB(r2, r2));
      cpu.setRegisters(r2: 0x12345678);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r2, 0x78);
    });

    test('should execute a `sxth r2, r5` instruction with sign bit 1', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeSXTH(r2, r5));
      cpu.setRegisters(r5: 0x22448765);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r2, 0xffff8765);
    });

    test(
      'should execute an `tst r1, r3` instruction when the result is negative',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeTST(r1, r3));
        cpu.setRegisters(r1: 0xf0000000);
        cpu.setRegisters(r3: 0xf0004000);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.N, true);
      },
    );

    test(
      'should execute an `tst r1, r3` instruction when the registers are different',
      () {
        cpu.setPC(0x20000000);
        cpu.writeUint16(0x20000000, opcodeTST(r1, r3));
        cpu.setRegisters(r1: 0xf0, r3: 0x0f);
        cpu.singleStep();
        final registers = cpu.readRegisters();
        expect(registers.Z, true);
      },
    );

    test('should execute an `uxtb r5, r3` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeUXTB(r5, r3));
      cpu.setRegisters(r3: 0x12345678);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r5, 0x78);
    });

    test('should execute an `uxth r3, r1` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeUXTH(r3, r1));
      cpu.setRegisters(r1: 0x12345678);
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.r3, 0x5678);
    });

    test('should execute a `wfi` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeWFI());
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000002);
    });

    test('should execute a `yield` instruction', () {
      cpu.setPC(0x20000000);
      cpu.writeUint16(0x20000000, opcodeYIELD());
      cpu.singleStep();
      final registers = cpu.readRegisters();
      expect(registers.pc, 0x20000002);
    });
  });
}
