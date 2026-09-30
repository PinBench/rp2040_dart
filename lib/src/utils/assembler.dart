// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'bit.dart';

int opcodeADCS(int Rdn, int Rm) {
  return (0x105 /* 0b0100000101 */ << 6) | ((Rm & 7) << 3) | (Rdn & 7);
}

int opcodeADDS1(int Rd, int Rn, int imm3) {
  return (0xe /* 0b0001110 */ << 9) |
      ((imm3 & 0x7) << 6) |
      ((Rn & 7) << 3) |
      (Rd & 7);
}

int opcodeADDS2(int Rdn, int imm8) {
  return (0x6 /* 0b00110 */ << 11) | ((Rdn & 7) << 8) | (imm8 & 0xff);
}

int opcodeADDspPlusImm(int Rd, int imm8) {
  return (0x15 /* 0b10101 */ << 11) | ((Rd & 7) << 8) | ((imm8 >> 2) & 0xff);
}

int opcodeADDsp2(int imm) {
  return (0x160 /* 0b101100000 */ << 7) | ((imm >> 2) & 0x7f);
}

int opcodeADDSreg(int Rd, int Rn, int Rm) {
  return (0xc /* 0b0001100 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 7) << 3) |
      (Rd & 7);
}

int opcodeADDreg(int Rdn, int Rm) {
  return (0x44 /* 0b01000100 */ << 8) |
      ((Rdn & 0x8) << 4) |
      ((Rm & 0xf) << 3) |
      (Rdn & 0x7);
}

int opcodeADR(int Rd, int imm8) {
  return (0x14 /* 0b10100 */ << 11) | ((Rd & 7) << 8) | ((imm8 >> 2) & 0xff);
}

int opcodeANDS(int Rn, int Rm) {
  return (0x100 /* 0b0100000000 */ << 6) | ((Rm & 7) << 3) | (Rn & 0x7);
}

int opcodeASRS(int Rd, int Rm, int imm5) {
  return (0x2 /* 0b00010 */ << 11) |
      ((imm5 & 0x1f) << 6) |
      ((Rm & 0x7) << 3) |
      (Rd & 0x7);
}

int opcodeASRSreg(int Rdn, int Rm) {
  return (0x104 /* 0b0100000100 */ << 6) |
      ((Rm & 0x7) << 3) |
      ((Rm & 0x7) << 3) |
      (Rdn & 0x7);
}

int opcodeBT1(int cond, int imm8) {
  return (0xd /* 0b1101 */ << 12) | ((cond & 0xf) << 8) | ((imm8 >> 1) & 0x1ff);
}

int opcodeBT2(int imm11) {
  return (0x1c /* 0b11100 */ << 11) | ((imm11 >> 1) & 0x7ff);
}

int opcodeBICS(int Rdn, int Rm) {
  return (0x10e /* 0b0100001110 */ << 6) | ((Rm & 7) << 3) | (Rdn & 7);
}

int opcodeBL(int imm) {
  final imm11 = (imm >> 1) & 0x7ff;
  final imm10 = (imm >> 12) & 0x3ff;
  final s = imm < 0 ? 1 : 0;
  final j2 = 1 - (((imm >> 22) & 0x1) ^ s);
  final j1 = 1 - (((imm >> 23) & 0x1) ^ s);
  final opcode =
      (0xd /* 0b1101 */ << 28) |
      (j1 << 29) |
      (j2 << 27) |
      (imm11 << 16) |
      (0x1e /* 0b11110 */ << 11) |
      (s << 10) |
      imm10;
  return u32(opcode);
}

int opcodeBLX(int Rm) {
  return (0x8f /* 0b010001111 */ << 7) | (Rm << 3);
}

int opcodeBX(int Rm) {
  return (0x8e /* 0b010001110 */ << 7) | (Rm << 3);
}

int opcodeCMN(int Rn, int Rm) {
  return (0x10b /* 0b0100001011 */ << 6) | ((Rm & 0x7) << 3) | (Rn & 0x7);
}

int opcodeCMPimm(int Rn, int Imm8) {
  return (0x5 /* 0b00101 */ << 11) | ((Rn & 0x7) << 8) | (Imm8 & 0xff);
}

int opcodeCMPregT1(int Rn, int Rm) {
  return (0x10a /* 0b0100001010 */ << 6) | ((Rm & 0x7) << 3) | (Rn & 0x7);
}

int opcodeCMPregT2(int Rn, int Rm) {
  return (0x45 /* 0b01000101 */ << 8) |
      (((Rn >> 3) & 0x1) << 7) |
      ((Rm & 0xf) << 3) |
      (Rn & 0x7);
}

int opcodeDMBSY() {
  return 0x8f50f3bf;
}

int opcodeDSBSY() {
  return 0x8f4ff3bf;
}

int opcodeEORS(int Rdn, int Rm) {
  return (0x101 /* 0b0100000001 */ << 6) | ((Rm & 0x7) << 3) | (Rdn & 0x7);
}

int opcodeISBSY() {
  return 0x8f6ff3bf;
}

int opcodeLDMIA(int Rn, int registers) {
  return (0x19 /* 0b11001 */ << 11) | ((Rn & 0x7) << 8) | (registers & 0xff);
}

int opcodeLDRreg(int Rt, int Rn, int Rm) {
  return (0x2c /* 0b0101100 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeLDRimm(int Rt, int Rn, int imm5) {
  return (0xd /* 0b01101 */ << 11) |
      (((imm5 >> 2) & 0x1f) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeLDRlit(int Rt, int imm8) {
  return (0x9 /* 0b01001 */ << 11) | ((imm8 >> 2) & 0xff) | ((Rt & 0x7) << 8);
}

int opcodeLDRB(int Rt, int Rn, int imm5) {
  return (0xf /* 0b01111 */ << 11) |
      ((imm5 & 0x1f) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeLDRsp(int Rt, int imm8) {
  return (0x13 /* 0b10011 */ << 11) | ((Rt & 7) << 8) | ((imm8 >> 2) & 0xff);
}

int opcodeLDRBreg(int Rt, int Rn, int Rm) {
  return (0x2e /* 0b0101110 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeLDRH(int Rt, int Rn, int imm5) {
  return (0x11 /* 0b10001 */ << 11) |
      (((imm5 >> 1) & 0xf) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeLDRHreg(int Rt, int Rn, int Rm) {
  return (0x2d /* 0b0101101 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeLDRSB(int Rt, int Rn, int Rm) {
  return (0x2b /* 0b0101011 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeLDRSH(int Rt, int Rn, int Rm) {
  return (0x2f /* 0b0101111 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeLSLSreg(int Rdn, int Rm) {
  return (0x102 /* 0b0100000010 */ << 6) | ((Rm & 0x7) << 3) | (Rdn & 0x7);
}

int opcodeLSLSimm(int Rd, int Rm, int Imm5) {
  return (0x0 /* 0b00000 */ << 11) |
      ((Imm5 & 0x1f) << 6) |
      ((Rm & 0x7) << 3) |
      (Rd & 0x7);
}

int opcodeLSRS(int Rd, int Rm, int imm5) {
  return (0x1 /* 0b00001 */ << 11) |
      ((imm5 & 0x1f) << 6) |
      ((Rm & 0x7) << 3) |
      (Rd & 0x7);
}

int opcodeLSRSreg(int Rdn, int Rm) {
  return (0x103 /* 0b0100000011 */ << 6) | ((Rm & 0x7) << 3) | (Rdn & 0x7);
}

int opcodeMOV(int Rd, int Rm) {
  return (0x46 /* 0b01000110 */ << 8) |
      (((Rd & 0x8) != 0 ? 1 : 0) << 7) |
      (Rm << 3) |
      (Rd & 0x7);
}

int opcodeMOVS(int Rd, int imm8) {
  return (0x4 /* 0b00100 */ << 11) | ((Rd & 0x7) << 8) | (imm8 & 0xff);
}

int opcodeMOVSreg(int Rd, int Rm) {
  return (0x0 /* 0b000000000 */ << 6) | ((Rm & 0x7) << 3) | (Rd & 0x7);
}

int opcodeMRS(int Rd, int specReg) {
  return u32(
    ((0x8 /* 0b1000 */ << 28) |
        ((Rd & 0xf) << 24) |
        ((specReg & 0xff) << 16) |
        0xf3ef /* 0b1111001111101111 */ ),
  );
}

int opcodeMSR(int specReg, int Rn) {
  return u32(
    ((0x88 /* 0b10001000 */ << 24) |
        ((specReg & 0xff) << 16) |
        (0xf38 /* 0b111100111000 */ << 4) |
        (Rn & 0xf)),
  );
}

int opcodeMULS(int Rn, int Rdm) {
  return (0x10d /* 0b0100001101 */ << 6) | ((Rn & 7) << 3) | (Rdm & 7);
}

int opcodeMVNS(int Rd, int Rm) {
  return (0x10f /* 0b0100001111 */ << 6) | ((Rm & 7) << 3) | (Rd & 7);
}

int opcodeNOP() {
  return 0xbf00 /* 0b1011111100000000 */;
}

int opcodeORRS(int Rn, int Rm) {
  return (0x10c /* 0b0100001100 */ << 6) | ((Rm & 0x7) << 3) | (Rn & 0x7);
}

int opcodePOP(bool P, int registerList) {
  return (0x5e /* 0b1011110 */ << 9) | ((P ? 1 : 0) << 8) | registerList;
}

int opcodePUSH(bool M, int registerList) {
  return (0x5a /* 0b1011010 */ << 9) | ((M ? 1 : 0) << 8) | registerList;
}

int opcodeREV(int Rd, int Rn) {
  return (0x2e8 /* 0b1011101000 */ << 6) | ((Rn & 0x7) << 3) | (Rd & 0x7);
}

int opcodeREV16(int Rd, int Rn) {
  return (0x2e9 /* 0b1011101001 */ << 6) | ((Rn & 0x7) << 3) | (Rd & 0x7);
}

int opcodeREVSH(int Rd, int Rn) {
  return (0x2eb /* 0b1011101011 */ << 6) | ((Rn & 0x7) << 3) | (Rd & 0x7);
}

int opcodeROR(int Rdn, int Rm) {
  return (0x107 /* 0b0100000111 */ << 6) | ((Rm & 0x7) << 3) | (Rdn & 0x7);
}

int opcodeRSBS(int Rd, int Rn) {
  return (0x109 /* 0b0100001001 */ << 6) | ((Rn & 0x7) << 3) | (Rd & 0x7);
}

int opcodeSBCS(int Rn, int Rm) {
  return (0x106 /* 0b0100000110 */ << 6) | ((Rm & 0x7) << 3) | (Rn & 0x7);
}

int opcodeSTMIA(int Rn, int registers) {
  return (0x18 /* 0b11000 */ << 11) | ((Rn & 0x7) << 8) | (registers & 0xff);
}

int opcodeSTR(int Rt, int Rm, int imm5) {
  return (0xc /* 0b01100 */ << 11) |
      (((imm5 >> 2) & 0x1f) << 6) |
      ((Rm & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeSTRsp(int Rt, int imm8) {
  return (0x12 /* 0b10010 */ << 11) | ((Rt & 7) << 8) | ((imm8 >> 2) & 0xff);
}

int opcodeSTRreg(int Rt, int Rn, int Rm) {
  return (0x28 /* 0b0101000 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeSTRB(int Rt, int Rm, int imm5) {
  return (0xe /* 0b01110 */ << 11) |
      ((imm5 & 0x1f) << 6) |
      ((Rm & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeSTRBreg(int Rt, int Rn, int Rm) {
  return (0x2a /* 0b0101010 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeSTRH(int Rt, int Rm, int imm5) {
  return (0x10 /* 0b10000 */ << 11) |
      (((imm5 >> 1) & 0x1f) << 6) |
      ((Rm & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeSTRHreg(int Rt, int Rn, int Rm) {
  return (0x29 /* 0b0101001 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 0x7) << 3) |
      (Rt & 0x7);
}

int opcodeSUBS1(int Rd, int Rn, int imm3) {
  return (0xf /* 0b0001111 */ << 9) |
      ((imm3 & 0x7) << 6) |
      ((Rn & 7) << 3) |
      (Rd & 7);
}

int opcodeSUBS2(int Rdn, int imm8) {
  return (0x7 /* 0b00111 */ << 11) | ((Rdn & 7) << 8) | (imm8 & 0xff);
}

int opcodeSUBSreg(int Rd, int Rn, int Rm) {
  return (0xd /* 0b0001101 */ << 9) |
      ((Rm & 0x7) << 6) |
      ((Rn & 7) << 3) |
      (Rd & 7);
}

int opcodeSUBsp(int imm) {
  return (0x161 /* 0b101100001 */ << 7) | ((imm >> 2) & 0x7f);
}

int opcodeSVC(int imm8) {
  return (0xdf /* 0b11011111 */ << 8) | (imm8 & 0xff);
}

int opcodeSXTB(int Rd, int Rm) {
  return (0x2c9 /* 0b1011001001 */ << 6) | ((Rm & 7) << 3) | (Rd & 7);
}

int opcodeSXTH(int Rd, int Rm) {
  return (0x2c8 /* 0b1011001000 */ << 6) | ((Rm & 7) << 3) | (Rd & 7);
}

int opcodeTST(int Rm, int Rn) {
  return (0x108 /* 0b0100001000 */ << 6) | ((Rn & 7) << 3) | (Rm & 7);
}

int opcodeUXTB(int Rd, int Rm) {
  return (0x2cb /* 0b1011001011 */ << 6) | ((Rm & 7) << 3) | (Rd & 7);
}

int opcodeUDF(int imm8) {
  return u32(((0xde /* 0b11011110 */ << 8) | (imm8 & 0xff)));
}

int opcodeUDF2(int imm16) {
  final imm12 = imm16 & 0xfff;
  final imm4 = (imm16 >> 12) & 0xf;
  return u32(
    ((0xf7f /* 0b111101111111 */ << 4) |
        imm4 |
        (0xa /* 0b1010 */ << 28) |
        (imm12 << 16)),
  );
}

int opcodeUXTH(int Rd, int Rm) {
  return (0x2ca /* 0b1011001010 */ << 6) | ((Rm & 7) << 3) | (Rd & 7);
}

int opcodeWFI() {
  return 0xbf30 /* 0b1011111100110000 */;
}

int opcodeYIELD() {
  return 0xbf10 /* 0b1011111100010000 */;
}
