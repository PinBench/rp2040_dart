// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

class ICortexRegisters {
  final int r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12;
  final int sp, lr, pc, xPSR, MSP, PSP, PRIMASK, CONTROL;
  final bool N, Z, C, V;

  const ICortexRegisters({
    required this.r0,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.r4,
    required this.r5,
    required this.r6,
    required this.r7,
    required this.r8,
    required this.r9,
    required this.r10,
    required this.r11,
    required this.r12,
    required this.sp,
    required this.lr,
    required this.pc,
    required this.xPSR,
    required this.MSP,
    required this.PSP,
    required this.PRIMASK,
    required this.CONTROL,
    required this.N,
    required this.Z,
    required this.C,
    required this.V,
  });
}

/// rp2040js's driver interface, synchronous: in Dart the only driver is the
/// in-process RP2040 one (no GDB-against-hardware driver).
///
/// `setRegisters` takes named arguments in place of TS's `Partial<ICortexRegisters>`
/// object and applies them in declaration order (r0..r12, sp, lr, pc, xPSR, MSP,
/// PSP, PRIMASK, CONTROL, N, Z, C, V), not in the order a call spells them.
abstract interface class ICortexTestDriver {
  void init();
  void setPC(int pcValue);
  void writeUint8(int address, int value);
  void writeUint16(int address, int value);
  void writeUint32(int address, int value);
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
  });
  void singleStep();
  ICortexRegisters readRegisters();
  int readUint8(int address);
  int readUint16(int address);
  int readUint32(int address);
  int readInt32(int address);
  void tearDown();
}
