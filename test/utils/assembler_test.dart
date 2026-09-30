// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/utils/assembler.dart';
import 'package:test/test.dart';

const int r0 = 0;
const int r1 = 1;
const int r2 = 2;
const int r3 = 3;
const int r4 = 4;
const int r5 = 5;
const int r6 = 6;
const int r7 = 7;
const int r8 = 8;
const int ip = 12;
const int lr = 14;

const int PRIMASK = 16;

void main() {
  group('assembler', () {
    test('should correctly encode an `adc r3, r0` instruction', () {
      expect(opcodeADCS(r3, r0), 0x4143);
    });

    test('should correctly encode an `add r1, sp, #4`', () {
      expect(opcodeADDspPlusImm(r1, 4), 0xa901);
    });

    test('should correctly encode an `add sp, #12` instruction', () {
      expect(opcodeADDsp2(12), 0xb003);
    });

    test('should correctly encode an `adds r0, r3, #0` instruction', () {
      expect(opcodeADDS1(r0, r3, 0), 0x1c18);
    });

    test('should correctly encode an `adds r1, r1, r3` instruction', () {
      expect(opcodeADDSreg(r1, r1, r3), 0x18c9);
    });

    test('should correctly encode an `add r1, ip` instruction', () {
      expect(opcodeADDreg(r1, ip), 0x4461);
    });

    test('should correctly encode an `adds r1, #1` instruction', () {
      expect(opcodeADDS2(r1, 1), 0x3101);
    });

    test('should correctly encode an `ands r5, r0` instruction', () {
      expect(opcodeANDS(r5, r0), 0x4005);
    });

    test('should correctly encode an `adr r4, #52` instruction', () {
      expect(opcodeADR(r4, 52), 0xa40d);
    });

    test('should correctly encode an `asrs r3, r2, #31` instruction', () {
      expect(opcodeASRS(r3, r2, 31), 0x17d3);
    });

    test('should correctly encode an `asrs r3, r4` instruction', () {
      expect(opcodeASRSreg(r3, r4), 0x4123);
    });

    test('should correctly encode an `b.n -20` instruction', () {
      expect(opcodeBT1(1, 0x1f8), 0xd1fc);
    });

    test('should correctly encode an `b.n -20` instruction', () {
      expect(opcodeBT2(0xfec), 0xe7f6);
    });

    test('should correctly encode an `bics r0, r3` instruction', () {
      expect(opcodeBICS(r0, r3), 0x4398);
    });

    test('should correctly encode an `bl .-198` instruction', () {
      expect(opcodeBL(-198), 0xff9df7ff);
    });

    test('should correctly encode an `bl .+10` instruction', () {
      expect(opcodeBL(10), 0xf805f000);
    });

    test('should correctly encode an `bl .-3242` instruction', () {
      expect(opcodeBL(-3242), 0xf9abf7ff);
    });

    test('should correctly encode an `blx r1` instruction', () {
      expect(opcodeBLX(r1), 0x4788);
    });

    test('should correctly encode an `bx lr` instruction', () {
      expect(opcodeBX(lr), 0x4770);
    });

    test('should correctly encode an `cmn r5, r6` instruction', () {
      expect(opcodeCMN(r5, r6), 0x42f5);
    });

    test('should correctly encode an `cmp r5, #66` instruction', () {
      expect(opcodeCMPimm(r5, 66), 0x2d42);
    });

    test('should correctly encode an `cmp r5, r0` instruction', () {
      expect(opcodeCMPregT1(r5, r0), 0x4285);
    });

    test('should correctly encode an `cmp ip (r12), r6` instruction', () {
      expect(opcodeCMPregT2(ip, r6), 0x45b4);
    });

    test('should correctly encode an `eors r1, r3` instruction', () {
      expect(opcodeEORS(r1, r3), 0x4059);
    });

    test('should correctly encode an `dmb sy` instruction', () {
      expect(opcodeDMBSY(), 0x8f50f3bf);
    });

    test('should correctly encode an `dsb sy` instruction', () {
      expect(opcodeDSBSY(), 0x8f4ff3bf);
    });

    test('should correctly encode an `ldmia r0!, {r1, r2}` instruction', () {
      expect(opcodeLDMIA(r0, (1 << r1) | (1 << r2)), 0xc806);
    });

    test('should correctly encode an `isb sy` instruction', () {
      expect(opcodeISBSY(), 0x8f6ff3bf);
    });

    test('should correctly encode an `lsls r5, r0` instruction', () {
      expect(opcodeLSLSreg(r5, r0), 0x4085);
    });

    test('should correctly encode an `lsrs r1, r1, #1` instruction', () {
      expect(opcodeLSRS(r1, r1, 1), 0x0849);
    });

    test('should correctly encode an `lsrs r0, r4` instruction', () {
      expect(opcodeLSRSreg(r0, r4), 0x40e0);
    });

    test('should correctly encode an `ldr r3, [r2, #24]', () {
      expect(opcodeLDRimm(r3, r2, 24), 0x6993);
    });

    test('should correctly encode an `ldr r0, [pc, #148]', () {
      expect(opcodeLDRlit(r0, 148), 0x4825);
    });

    test('should correctly encode an `ldr r3, [r3, r4]', () {
      expect(opcodeLDRreg(r3, r3, r4), 0x591b);
    });

    test('should correctly encode an `ldr r3, [sp, #12]', () {
      expect(opcodeLDRsp(r3, 12), 0x9b03);
    });

    test('should correctly encode an `ldrb r0, [r1, #0]` instruction', () {
      expect(opcodeLDRB(r0, r1, 0), 0x7808);
    });

    test('should correctly encode an `ldrb r2, [r5, r4]` instruction', () {
      expect(opcodeLDRBreg(r2, r5, r4), 0x5d2a);
    });

    test('should correctly encode an `ldrh r3, [r0, #2]` instruction', () {
      expect(opcodeLDRH(r3, r0, 2), 0x8843);
    });

    test('should correctly encode an `ldrh r4, [r0, r1]` instruction', () {
      expect(opcodeLDRHreg(r4, r0, r1), 0x5a44);
    });

    test('should correctly encode an `ldrsb r3, [r2, r3]` instruction', () {
      expect(opcodeLDRSB(r3, r2, r3), 0x56d3);
    });

    test('should correctly encode an `ldrsh r5, [r3, r5]` instruction', () {
      expect(opcodeLDRSH(r5, r3, r5), 0x5f5d);
    });

    test('should correctly encode an `lsls r5, r5, #18]` instruction', () {
      expect(opcodeLSLSimm(r5, r5, 18), 0x04ad);
    });

    test('should correctly encode an `mov r3, r8` instruction', () {
      expect(opcodeMOV(r3, r8), 0x4643);
    });

    test('should correctly encode an `movs r5, #128` instruction', () {
      expect(opcodeMOVS(r5, 128), 0x2580);
    });

    test('should correctly encode an `movs r6, r5` instruction', () {
      expect(opcodeMOVSreg(r6, r5), 0x002e);
    });

    test('should correctly encode an `mrs r6, PRIMASK` instruction', () {
      expect(opcodeMRS(r6, PRIMASK), 0x8610f3ef);
    });

    test('should correctly encode an `msr PRIMASK, r6` instruction', () {
      expect(opcodeMSR(PRIMASK, r6), 0x8810f386);
    });

    test('should correctly encode an `muls r2, r0` instruction', () {
      expect(opcodeMULS(r2, r0), 0x4350);
    });

    test('should correctly encode an `mvns r3, r3` instruction', () {
      expect(opcodeMVNS(r3, r3), 0x43db);
    });

    test('should correctly encode an `orrs r3, r0` instruction', () {
      expect(opcodeORRS(r3, r0), 0x4303);
    });

    test('should correctly encode an `pop {r0, r1, pc}` instruction', () {
      expect(opcodePOP(true, (1 << r0) | (1 << r1)), 0xbd03);
    });

    test('should correctly encode an `push {r4, r5, r6, lr}` instruction', () {
      expect(opcodePUSH(true, (1 << r4) | (1 << r5) | (1 << r6)), 0xb570);
    });

    test('should correctly encode an `rev r3, r1` instruction', () {
      expect(opcodeREV(r3, r1), 0xba0b);
    });

    test('should correctly encode an `rev16 r2, r7` instruction', () {
      expect(opcodeREV16(r2, r7), 0xba7a);
    });

    test('should correctly encode an `revsh r1, r5` instruction', () {
      expect(opcodeREVSH(r1, r5), 0xbae9);
    });

    test('should correctly encode an `rors r6, r0` instruction', () {
      expect(opcodeROR(r6, r0), 0x41c6);
    });

    test('should correctly encode an `rsbs r0, r3` instruction', () {
      expect(opcodeRSBS(r0, r3), 0x4258);
    });

    test('should correctly encode an `sbcs r0, r3` instruction', () {
      expect(opcodeSBCS(r0, r3), 0x4198);
    });

    test('should correctly encode an `stmia r2!, {r0}` instruction', () {
      expect(opcodeSTMIA(r2, 1 << r0), 0xc201);
    });

    test('should correctly encode an `str r6, [r4, #20]` instruction', () {
      expect(opcodeSTR(r6, r4, 20), 0x6166);
    });

    test('should correctly encode an `str r1, [sp, #4]` instruction', () {
      expect(opcodeSTRsp(r1, 4), 0x9101);
    });

    test('should correctly encode an `str r2, [r1, r4]` instruction', () {
      expect(opcodeSTRreg(r2, r1, r4), 0x510a);
    });

    test('should correctly encode an `strb r3, [r2, #0]` instruction', () {
      expect(opcodeSTRB(r3, r2, 0), 0x7013);
    });

    test('should correctly encode an `strb r3, [r2, r5]` instruction', () {
      expect(opcodeSTRBreg(r3, r2, r5), 0x5553);
    });

    test('should correctly encode an `strh r1, [r3, #4]` instruction', () {
      expect(opcodeSTRH(r1, r3, 4), 0x8099);
    });

    test('should correctly encode an `strh r1, [r3, r2]` instruction', () {
      expect(opcodeSTRHreg(r1, r3, r2), 0x5299);
    });

    test('should correctly encode an `sub sp, #12` instruction', () {
      expect(opcodeSUBsp(12), 0xb083);
    });

    test('should correctly encode an `subs r3, r0, #1` instruction', () {
      expect(opcodeSUBS1(r3, r0, 1), 0x1e43);
    });

    test('should correctly encode an `subs r1, r1, r0` instruction', () {
      expect(opcodeSUBSreg(r1, r1, r0), 0x1a09);
    });

    test('should correctly encode an `subs r3, #13` instruction', () {
      expect(opcodeSUBS2(r3, 13), 0x3b0d);
    });

    test('should correctly encode an `svc 0` instruction', () {
      expect(opcodeSVC(0), 0xdf00);
    });

    test('should correctly encode an `sxtb r2, r2` instruction', () {
      expect(opcodeSXTB(r2, r2), 0xb252);
    });

    test('should correctly encode an `sxth r6, r3` instruction', () {
      expect(opcodeSXTH(r6, r3), 0xb21e);
    });

    test('should correctly encode an `tst r1,r3` instruction', () {
      expect(opcodeTST(r1, r3), 0x4219);
    });

    test('should correctly encode an `udf #1` instruction', () {
      expect(opcodeUDF(1), 0xde01);
    });

    test('should correctly encode an `udf.w #0` instruction', () {
      expect(opcodeUDF2(0), 0xa000f7f0);
    });

    test('should correctly encode an `uxtb r3, r3` instruction', () {
      expect(opcodeUXTB(r3, r3), 0xb2db);
    });

    test('should correctly encode `uxth r3, r0', () {
      expect(opcodeUXTH(r3, r0), 0xb283);
    });
  });
}
