// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/cortex_m0_core.dart';
import 'package:rp2040_dart/src/rp2040.dart';
import 'package:rp2040_dart/src/utils/bit.dart';

import 'test_driver.dart';

class RP2040TestDriver implements ICortexTestDriver {
  final RP2040 rp2040;

  RP2040TestDriver(this.rp2040);

  @override
  void init() {
    /* this page intentionally left blank ! */
  }

  @override
  void tearDown() {
    rp2040.pio[0].stop();
    rp2040.pio[1].stop();
  }

  @override
  void setPC(int pcValue) {
    rp2040.core.PC = pcValue;
  }

  @override
  void writeUint8(int address, int value) {
    rp2040.writeUint8(address, value);
  }

  @override
  void writeUint16(int address, int value) {
    rp2040.writeUint16(address, value);
  }

  @override
  void writeUint32(int address, int value) {
    rp2040.writeUint32(address, value);
  }

  @override
  void setRegisters({
    int? r0,
    int? r1,
    int? r2,
    int? r3,
    int? r4,
    int? r5,
    int? r6,
    int? r7,
    int? r8,
    int? r9,
    int? r10,
    int? r11,
    int? r12,
    int? sp,
    int? lr,
    int? pc,
    int? xPSR,
    int? MSP,
    int? PSP,
    int? PRIMASK,
    int? CONTROL,
    bool? N,
    bool? Z,
    bool? C,
    bool? V,
  }) {
    final core = rp2040.core;
    final general = [
      r0,
      r1,
      r2,
      r3,
      r4,
      r5,
      r6,
      r7,
      r8,
      r9,
      r10,
      r11,
      r12,
      sp,
      lr,
      pc,
    ];
    for (var i = 0; i < general.length; i++) {
      final value = general[i];
      if (value != null) {
        core.registers[i] = u32(value);
      }
    }
    if (xPSR != null) core.xPSR = u32(xPSR);
    if (MSP != null) core.writeSpecialRegister(SYSM_MSP, u32(MSP));
    if (PSP != null) core.writeSpecialRegister(SYSM_PSP, u32(PSP));
    if (PRIMASK != null) core.writeSpecialRegister(SYSM_PRIMASK, u32(PRIMASK));
    if (CONTROL != null) core.writeSpecialRegister(SYSM_CONTROL, u32(CONTROL));
    if (N != null) core.N = N;
    if (Z != null) core.Z = Z;
    if (C != null) core.C = C;
    if (V != null) core.V = V;
  }

  @override
  void singleStep() {
    rp2040.step();
  }

  @override
  ICortexRegisters readRegisters() {
    final core = rp2040.core;
    final registers = core.registers;
    final xPSR = core.xPSR;
    return ICortexRegisters(
      r0: registers[0],
      r1: registers[1],
      r2: registers[2],
      r3: registers[3],
      r4: registers[4],
      r5: registers[5],
      r6: registers[6],
      r7: registers[7],
      r8: registers[8],
      r9: registers[9],
      r10: registers[10],
      r11: registers[11],
      r12: registers[12],
      sp: registers[13],
      lr: registers[14],
      pc: registers[15],
      xPSR: xPSR,
      MSP: core.readSpecialRegister(SYSM_MSP),
      PSP: core.readSpecialRegister(SYSM_PSP),
      PRIMASK: core.readSpecialRegister(SYSM_PRIMASK),
      CONTROL: core.readSpecialRegister(SYSM_CONTROL),
      N: xPSR & 0x80000000 != 0,
      Z: xPSR & 0x40000000 != 0,
      C: xPSR & 0x20000000 != 0,
      V: xPSR & 0x10000000 != 0,
    );
  }

  @override
  int readUint8(int address) => rp2040.readUint8(address);

  @override
  int readUint16(int address) => rp2040.readUint16(address);

  @override
  int readUint32(int address) => u32(rp2040.readUint32(address));

  @override
  int readInt32(int address) => s32(rp2040.readUint32(address));
}
