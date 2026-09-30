// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:math' as math;
import 'dart:typed_data';

import 'irq.dart';
import 'rp2040.dart';
import 'utils/bit.dart';
import 'utils/logging.dart';

const int _EXC_RESET = 1;
const int _EXC_NMI = 2;
const int _EXC_HARDFAULT = 3;
const int _EXC_SVCALL = 11;
const int _EXC_PENDSV = 14;
const int _EXC_SYSTICK = 15;

const int _SYSM_APSR = 0;
// ignore: unused_element
const int _SYSM_IAPSR = 1;
// ignore: unused_element
const int _SYSM_EAPSR = 2;
const int _SYSM_XPSR = 3;
const int _SYSM_IPSR = 5;
// ignore: unused_element
const int _SYSM_EPSR = 6;
// ignore: unused_element
const int _SYSM_IEPSR = 7;
const int SYSM_MSP = 8;
const int SYSM_PSP = 9;
const int SYSM_PRIMASK = 16;
const int SYSM_CONTROL = 20;

// Lowest possible exception priority
const int _LOWEST_PRIORITY = 4;

enum ExecutionMode { Mode_Thread, Mode_Handler }

/// TS `(value << 24) >> 24`, as an unsigned 32-bit value.
int _signExtend8(int value) {
  return u32(value.toSigned(8));
}

/// TS `(value << 16) >> 16`, as an unsigned 32-bit value.
int _signExtend16(int value) {
  return u32(value.toSigned(16));
}

const int _spRegister = 13;
const int _pcRegister = 15;

enum StackPointerBank { SPmain, SPprocess }

const String _LOG_NAME = 'CortexM0Core';

/// Which case of [CortexM0Core.executeInstruction] a 16-bit opcode runs: 1..83,
/// or 0 for none (the "not implemented" warning).
///
/// Built from [_decode], which runs the if-chain this replaced (rp2040js's), in
/// the same order, so every instruction still runs exactly the case it always
/// did. A 32-bit instruction (first half-word `0b1111...` or `0b11101...`) is
/// marked [_decodeWide] instead: seven of its cases also test the second
/// half-word, so it is decoded when it runs, from both half-words.
final Uint8List _decodeTable = _buildDecodeTable();

const int _decodeWide = 255;

Uint8List _buildDecodeTable() {
  final table = Uint8List(0x10000);
  for (var opcode = 0; opcode < 0x10000; opcode++) {
    final wide = opcode >> 12 == 0xf || opcode >> 11 == 0x1d;
    table[opcode] = wide ? _decodeWide : _decode(opcode, 0);
  }
  return table;
}

int _decode(int opcode, int opcode2) {
  // ADCS
  if (opcode >> 6 == 0x105 /* 0b0100000101 */ ) {
    return 1;
  }
  // ADD (register = SP plus immediate)
  if (opcode >> 11 == 0x15 /* 0b10101 */ ) {
    return 2;
  }
  // ADD (SP plus immediate)
  if (opcode >> 7 == 0x160 /* 0b101100000 */ ) {
    return 3;
  }
  // ADDS (Encoding T1)
  if (opcode >> 9 == 0xe /* 0b0001110 */ ) {
    return 4;
  }
  // ADDS (Encoding T2)
  if (opcode >> 11 == 0x6 /* 0b00110 */ ) {
    return 5;
  }
  // ADDS (register)
  if (opcode >> 9 == 0xc /* 0b0001100 */ ) {
    return 6;
  }
  // ADD (register)
  if (opcode >> 8 == 0x44 /* 0b01000100 */ ) {
    return 7;
  }
  // ADR
  if (opcode >> 11 == 0x14 /* 0b10100 */ ) {
    return 8;
  }
  // ANDS (Encoding T2)
  if (opcode >> 6 == 0x100 /* 0b0100000000 */ ) {
    return 9;
  }
  // ASRS (immediate)
  if (opcode >> 11 == 0x2 /* 0b00010 */ ) {
    return 10;
  }
  // ASRS (register)
  if (opcode >> 6 == 0x104 /* 0b0100000100 */ ) {
    return 11;
  }
  // B (with cond)
  if (opcode >> 12 == 0xd /* 0b1101 */ && ((opcode >> 9) & 0x7) != 0x7) {
    return 12;
  }
  // B
  if (opcode >> 11 == 0x1c /* 0b11100 */ ) {
    return 13;
  }
  // BICS
  if (opcode >> 6 == 0x10e /* 0b0100001110 */ ) {
    return 14;
  }
  // BKPT
  if (opcode >> 8 == 0xbe /* 0b10111110 */ ) {
    return 15;
  }
  if (opcode >> 11 == 0x1e /* 0b11110 */ &&
      opcode2 >> 14 == 0x3 &&
      ((opcode2 >> 12) & 0x1) == 1) {
    return 16;
  }
  // BLX
  if (opcode >> 7 == 0x8f /* 0b010001111 */ && (opcode & 0x7) == 0) {
    return 17;
  }
  // BX
  if (opcode >> 7 == 0x8e /* 0b010001110 */ && (opcode & 0x7) == 0) {
    return 18;
  }
  // CMN (register)
  if (opcode >> 6 == 0x10b /* 0b0100001011 */ ) {
    return 19;
  }
  // CMP immediate
  if (opcode >> 11 == 0x5 /* 0b00101 */ ) {
    return 20;
  }
  // CMP (register)
  if (opcode >> 6 == 0x10a /* 0b0100001010 */ ) {
    return 21;
  }
  // CMP (register) encoding T2
  if (opcode >> 8 == 0x45 /* 0b01000101 */ ) {
    return 22;
  }
  // CPSID i
  if (opcode == 0xb672) {
    return 23;
  }
  // CPSIE i
  if (opcode == 0xb662) {
    return 24;
  }
  // DMB SY
  if (opcode == 0xf3bf && (opcode2 & 0xfff0) == 0x8f50) {
    return 25;
  }
  // DSB SY
  if (opcode == 0xf3bf && (opcode2 & 0xfff0) == 0x8f40) {
    return 26;
  }
  // EORS
  if (opcode >> 6 == 0x101 /* 0b0100000001 */ ) {
    return 27;
  }
  // ISB SY
  if (opcode == 0xf3bf && (opcode2 & 0xfff0) == 0x8f60) {
    return 28;
  }
  // LDMIA
  if (opcode >> 11 == 0x19 /* 0b11001 */ ) {
    return 29;
  }
  // LDR (immediate)
  if (opcode >> 11 == 0xd /* 0b01101 */ ) {
    return 30;
  }
  // LDR (sp + immediate)
  if (opcode >> 11 == 0x13 /* 0b10011 */ ) {
    return 31;
  }
  // LDR (literal)
  if (opcode >> 11 == 0x9 /* 0b01001 */ ) {
    return 32;
  }
  // LDR (register)
  if (opcode >> 9 == 0x2c /* 0b0101100 */ ) {
    return 33;
  }
  // LDRB (immediate)
  if (opcode >> 11 == 0xf /* 0b01111 */ ) {
    return 34;
  }
  // LDRB (register)
  if (opcode >> 9 == 0x2e /* 0b0101110 */ ) {
    return 35;
  }
  // LDRH (immediate)
  if (opcode >> 11 == 0x11 /* 0b10001 */ ) {
    return 36;
  }
  // LDRH (register)
  if (opcode >> 9 == 0x2d /* 0b0101101 */ ) {
    return 37;
  }
  // LDRSB
  if (opcode >> 9 == 0x2b /* 0b0101011 */ ) {
    return 38;
  }
  // LDRSH
  if (opcode >> 9 == 0x2f /* 0b0101111 */ ) {
    return 39;
  }
  // LSLS (immediate)
  if (opcode >> 11 == 0x0 /* 0b00000 */ ) {
    return 40;
  }
  // LSLS (register)
  if (opcode >> 6 == 0x102 /* 0b0100000010 */ ) {
    return 41;
  }
  // LSRS (immediate)
  if (opcode >> 11 == 0x1 /* 0b00001 */ ) {
    return 42;
  }
  // LSRS (register)
  if (opcode >> 6 == 0x103 /* 0b0100000011 */ ) {
    return 43;
  }
  // MOV
  if (opcode >> 8 == 0x46 /* 0b01000110 */ ) {
    return 44;
  }
  // MOVS
  if (opcode >> 11 == 0x4 /* 0b00100 */ ) {
    return 45;
  }
  // MRS
  if (opcode == 0xf3ef /* 0b1111001111101111 */ && opcode2 >> 12 == 0x8) {
    return 46;
  }
  if (opcode >> 4 == 0xf38 /* 0b111100111000 */ &&
      opcode2 >> 8 == 0x88 /* 0b10001000 */ ) {
    return 47;
  }
  // MULS
  if (opcode >> 6 == 0x10d /* 0b0100001101 */ ) {
    return 48;
  }
  // MVNS
  if (opcode >> 6 == 0x10f /* 0b0100001111 */ ) {
    return 49;
  }
  // ORRS (Encoding T2)
  if (opcode >> 6 == 0x10c /* 0b0100001100 */ ) {
    return 50;
  }
  // POP
  if (opcode >> 9 == 0x5e /* 0b1011110 */ ) {
    return 51;
  }
  // PUSH
  if (opcode >> 9 == 0x5a /* 0b1011010 */ ) {
    return 52;
  }
  // REV
  if (opcode >> 6 == 0x2e8 /* 0b1011101000 */ ) {
    return 53;
  }
  // REV16
  if (opcode >> 6 == 0x2e9 /* 0b1011101001 */ ) {
    return 54;
  }
  // REVSH
  if (opcode >> 6 == 0x2eb /* 0b1011101011 */ ) {
    return 55;
  }
  // ROR
  if (opcode >> 6 == 0x107 /* 0b0100000111 */ ) {
    return 56;
  }
  // NEGS / RSBS
  if (opcode >> 6 == 0x109 /* 0b0100001001 */ ) {
    return 57;
  }
  // NOP
  if (opcode == 0xbf00 /* 0b1011111100000000 */ ) {
    return 58;
  }
  // SBCS (Encoding T1)
  if (opcode >> 6 == 0x106 /* 0b0100000110 */ ) {
    return 59;
  }
  // SEV
  if (opcode == 0xbf40 /* 0b1011111101000000 */ ) {
    return 60;
  }
  // STMIA
  if (opcode >> 11 == 0x18 /* 0b11000 */ ) {
    return 61;
  }
  // STR (immediate)
  if (opcode >> 11 == 0xc /* 0b01100 */ ) {
    return 62;
  }
  // STR (sp + immediate)
  if (opcode >> 11 == 0x12 /* 0b10010 */ ) {
    return 63;
  }
  // STR (register)
  if (opcode >> 9 == 0x28 /* 0b0101000 */ ) {
    return 64;
  }
  // STRB (immediate)
  if (opcode >> 11 == 0xe /* 0b01110 */ ) {
    return 65;
  }
  // STRB (register)
  if (opcode >> 9 == 0x2a /* 0b0101010 */ ) {
    return 66;
  }
  // STRH (immediate)
  if (opcode >> 11 == 0x10 /* 0b10000 */ ) {
    return 67;
  }
  // STRH (register)
  if (opcode >> 9 == 0x29 /* 0b0101001 */ ) {
    return 68;
  }
  // SUB (SP minus immediate)
  if (opcode >> 7 == 0x161 /* 0b101100001 */ ) {
    return 69;
  }
  // SUBS (Encoding T1)
  if (opcode >> 9 == 0xf /* 0b0001111 */ ) {
    return 70;
  }
  // SUBS (Encoding T2)
  if (opcode >> 11 == 0x7 /* 0b00111 */ ) {
    return 71;
  }
  // SUBS (register)
  if (opcode >> 9 == 0xd /* 0b0001101 */ ) {
    return 72;
  }
  // SVC
  if (opcode >> 8 == 0xdf /* 0b11011111 */ ) {
    return 73;
  }
  // SXTB
  if (opcode >> 6 == 0x2c9 /* 0b1011001001 */ ) {
    return 74;
  }
  // SXTH
  if (opcode >> 6 == 0x2c8 /* 0b1011001000 */ ) {
    return 75;
  }
  // TST
  if (opcode >> 6 == 0x108 /* 0b0100001000 */ ) {
    return 76;
  }
  // UDF
  if (opcode >> 8 == 0xde /* 0b11011110 */ ) {
    return 77;
  }
  if (opcode >> 4 == 0xf7f /* 0b111101111111 */ &&
      opcode2 >> 12 == 0xa /* 0b1010 */ ) {
    return 78;
  }
  // UXTB
  if (opcode >> 6 == 0x2cb /* 0b1011001011 */ ) {
    return 79;
  }
  // UXTH
  if (opcode >> 6 == 0x2ca /* 0b1011001010 */ ) {
    return 80;
  }
  // WFE
  if (opcode == 0xbf20 /* 0b1011111100100000 */ ) {
    return 81;
  }
  // WFI
  if (opcode == 0xbf30 /* 0b1011111100110000 */ ) {
    return 82;
  }
  // YIELD
  if (opcode == 0xbf10 /* 0b1011111100010000 */ ) {
    return 83;
  }
  return 0;
}

class CortexM0Core {
  final Uint32List registers = Uint32List(16);

  /// [_decodeTable], held per core: a top-level `final` is initialised lazily,
  /// so every read of it pays an initialisation check, where an instance field
  /// read does not. [executeInstruction] reads it for every instruction.
  final Uint8List decodeTable = _decodeTable;
  int bankedSP = 0;
  int cycles = 0;

  bool eventRegistered = false;
  bool waiting = false;

  // APSR fields
  bool N = false;
  bool C = false;
  bool Z = false;
  bool V = false;

  // How many bytes to rewind the last break instruction
  int breakRewind = 0;

  // PRIMASK fields
  bool PM = false;

  // CONTROL fields
  StackPointerBank SPSEL = StackPointerBank.SPmain;
  bool nPRIV = false;

  ExecutionMode currentMode = ExecutionMode.Mode_Thread;
  int IPSR = 0;
  int interruptNMIMask = 0;
  int pendingInterrupts = 0;
  int enabledInterrupts = 0;
  // A Uint32List (rp2040js: a plain array) so every write stays in [0, 0xFFFFFFFF].
  Uint32List interruptPriorities = Uint32List.fromList([
    0xffffffff,
    0x0,
    0x0,
    0x0,
  ]);
  bool pendingNMI = false;
  bool pendingPendSV = false;
  bool pendingSVCall = false;
  bool pendingSystick = false;
  bool interruptsUpdated = false;
  int VTOR = 0;
  int SHPR2 = 0;
  int SHPR3 = 0;

  /// Hook to listen for function calls - branch-link (BL/BLX) instructions
  void Function(CortexM0Core core, bool blx) blTaken = (core, blx) {};

  final RP2040 rp2040;

  CortexM0Core(this.rp2040) {
    SP = 0xfffffffc;
    bankedSP = 0xfffffffc;
  }

  Logger get logger {
    return rp2040.logger;
  }

  void reset() {
    SP = rp2040.readUint32(VTOR);
    PC = rp2040.readUint32(VTOR + 4) & 0xfffffffe;
    cycles = 0;
  }

  int get SP {
    return registers[13];
  }

  set SP(int value) {
    registers[13] = u32(value & ~0x3);
  }

  int get LR {
    return registers[14];
  }

  set LR(int value) {
    registers[14] = value;
  }

  int get PC {
    return registers[15];
  }

  set PC(int value) {
    registers[15] = value;
  }

  int get APSR {
    return (N ? 0x80000000 : 0) |
        (Z ? 0x40000000 : 0) |
        (C ? 0x20000000 : 0) |
        (V ? 0x10000000 : 0);
  }

  set APSR(int value) {
    N = value & 0x80000000 != 0;
    Z = value & 0x40000000 != 0;
    C = value & 0x20000000 != 0;
    V = value & 0x10000000 != 0;
  }

  int get xPSR {
    return APSR | IPSR | (1 << 24);
  }

  set xPSR(int value) {
    APSR = value;
    IPSR = value & 0x3f;
  }

  bool checkCondition(int cond) {
    // Evaluate base condition.
    var result = false;
    switch (cond >> 1) {
      case 0x0: // 0b000
        result = Z;
        break;
      case 0x1: // 0b001
        result = C;
        break;
      case 0x2: // 0b010
        result = N;
        break;
      case 0x3: // 0b011
        result = V;
        break;
      case 0x4: // 0b100
        result = C && !Z;
        break;
      case 0x5: // 0b101
        result = N == V;
        break;
      case 0x6: // 0b110
        result = N == V && !Z;
        break;
      case 0x7: // 0b111
        result = true;
        break;
    }
    return (cond & 0x1) != 0 && cond != 0xf ? !result : result;
  }

  int readUint32(int address) {
    return rp2040.readUint32(address);
  }

  int readUint16(int address) {
    return rp2040.readUint16(address);
  }

  int readUint8(int address) {
    return rp2040.readUint8(address);
  }

  void writeUint32(int address, int value) {
    rp2040.writeUint32(address, value);
  }

  void writeUint16(int address, int value) {
    rp2040.writeUint16(address, value);
  }

  void writeUint8(int address, int value) {
    rp2040.writeUint8(address, value);
  }

  void switchStack(StackPointerBank stack) {
    if (SPSEL != stack) {
      final temp = SP;
      SP = bankedSP;
      bankedSP = temp;
      SPSEL = stack;
    }
  }

  int get SPprocess {
    return SPSEL == StackPointerBank.SPprocess ? SP : bankedSP;
  }

  set SPprocess(int value) {
    if (SPSEL == StackPointerBank.SPprocess) {
      SP = value;
    } else {
      bankedSP = u32(value);
    }
  }

  int get SPmain {
    return SPSEL == StackPointerBank.SPmain ? SP : bankedSP;
  }

  set SPmain(int value) {
    if (SPSEL == StackPointerBank.SPmain) {
      SP = value;
    } else {
      bankedSP = u32(value);
    }
  }

  void exceptionEntry(int exceptionNumber) {
    // PushStack:
    var framePtr = 0;
    var framePtrAlign = 0;
    if (SPSEL == StackPointerBank.SPprocess &&
        currentMode == ExecutionMode.Mode_Thread) {
      framePtrAlign = SPprocess & 0x4 != 0 ? 1 : 0;
      SPprocess = u32((SPprocess - 0x20) & ~0x4);
      framePtr = SPprocess;
    } else {
      framePtrAlign = SPmain & 0x4 != 0 ? 1 : 0;
      SPmain = u32((SPmain - 0x20) & ~0x4);
      framePtr = SPmain;
    }
    /* only the stack locations, not the store order, are architected */
    writeUint32(framePtr, registers[0]);
    writeUint32(framePtr + 0x4, registers[1]);
    writeUint32(framePtr + 0x8, registers[2]);
    writeUint32(framePtr + 0xc, registers[3]);
    writeUint32(framePtr + 0x10, registers[12]);
    writeUint32(framePtr + 0x14, LR);
    writeUint32(framePtr + 0x18, PC & ~1); // ReturnAddress(ExceptionType);
    writeUint32(
      framePtr + 0x1c,
      u32((xPSR & ~(1 << 9)) | (framePtrAlign << 9)),
    );
    if (currentMode == ExecutionMode.Mode_Handler) {
      LR = 0xfffffff1;
    } else {
      if (SPSEL == StackPointerBank.SPmain) {
        LR = 0xfffffff9;
      } else {
        LR = 0xfffffffd;
      }
    }
    // ExceptionTaken:
    currentMode =
        ExecutionMode.Mode_Handler; // Enter Handler Mode, now Privileged
    IPSR = exceptionNumber;
    switchStack(StackPointerBank.SPmain);
    eventRegistered = true;
    final vectorTable = VTOR;
    PC = readUint32(vectorTable + 4 * exceptionNumber);
  }

  void exceptionReturn(int excReturn) {
    var framePtr = SPmain;
    switch (excReturn & 0xf) {
      case 0x1: // 0b0001: Return to Handler
        currentMode = ExecutionMode.Mode_Handler;
        switchStack(StackPointerBank.SPmain);
        break;
      case 0x9: // 0b1001: Return to Thread using Main stack
        currentMode = ExecutionMode.Mode_Thread;
        switchStack(StackPointerBank.SPmain);
        break;
      case 0xd: // 0b1101: Return to Thread using Process stack
        framePtr = SPprocess;
        currentMode = ExecutionMode.Mode_Thread;
        switchStack(StackPointerBank.SPprocess);
        break;
      // Assigning CurrentMode to Mode_Thread causes a drop in privilege
      // if CONTROL.nPRIV is set to 1
    }

    // PopStack:
    registers[0] = readUint32(
      framePtr,
    ); // Stack accesses are performed as Unprivileged accesses if
    registers[1] = readUint32(
      framePtr + 0x4,
    ); // CONTROL<0>=='1' && EXC_RETURN<3>=='1' Privileged otherwise
    registers[2] = readUint32(framePtr + 0x8);
    registers[3] = readUint32(framePtr + 0xc);
    registers[12] = readUint32(framePtr + 0x10);
    LR = readUint32(framePtr + 0x14);
    PC = readUint32(framePtr + 0x18);
    final psr = readUint32(framePtr + 0x1c);

    final framePtrAlign = psr & (1 << 9) != 0 ? 0x4 : 0;

    switch (excReturn & 0xf) {
      case 0x1: // 0b0001: Returning to Handler mode
        SPmain = (SPmain + 0x20) | framePtrAlign;
        break;

      case 0x9: // 0b1001: Returning to Thread mode using Main stack
        SPmain = (SPmain + 0x20) | framePtrAlign;
        break;

      case 0xd: // 0b1101: Returning to Thread mode using Process stack
        SPprocess = (SPprocess + 0x20) | framePtrAlign;
        break;
    }

    APSR = psr & 0xf0000000;
    final forceThread = currentMode == ExecutionMode.Mode_Thread && nPRIV;
    IPSR = forceThread ? 0 : psr & 0x3f;
    interruptsUpdated = true;
    // Thumb bit should always be one! EPSR<24> = psr<24>; // Load valid EPSR bits from memory
    eventRegistered = true;
    // if CurrentMode == Mode_Thread && SCR.SLEEPONEXIT == '1' then
    // SleepOnExit(); // IMPLEMENTATION DEFINED
  }

  int get pendSVPriority {
    return (SHPR3 >> 22) & 0x3;
  }

  int get svCallPriority {
    return u32(SHPR2) >>> 30;
  }

  int get systickPriority {
    return u32(SHPR3) >>> 30;
  }

  int exceptionPriority(int n) {
    switch (n) {
      case _EXC_RESET:
        return -3;
      case _EXC_NMI:
        return -2;
      case _EXC_HARDFAULT:
        return -1;
      case _EXC_SVCALL:
        return svCallPriority;
      case _EXC_PENDSV:
        return pendSVPriority;
      case _EXC_SYSTICK:
        return systickPriority;
      default:
        {
          if (n < 16) {
            return _LOWEST_PRIORITY;
          }
          final intNum = n - 16;
          for (var priority = 0; priority < 4; priority++) {
            // JS shift counts are mod 32
            if (interruptPriorities[priority] & (1 << (intNum & 31)) != 0) {
              return priority;
            }
          }
          return _LOWEST_PRIORITY;
        }
    }
  }

  int get vectPending {
    if (pendingNMI) {
      return _EXC_NMI;
    }
    final svCallPriority = this.svCallPriority;
    final systickPriority = this.systickPriority;
    final pendSVPriority = this.pendSVPriority;
    final pendingInterrupts = this.pendingInterrupts;
    for (var priority = 0; priority < _LOWEST_PRIORITY; priority++) {
      final levelInterrupts = pendingInterrupts & interruptPriorities[priority];
      if (pendingSVCall && priority == svCallPriority) {
        return _EXC_SVCALL;
      }
      if (pendingPendSV && priority == pendSVPriority) {
        return _EXC_PENDSV;
      }
      if (pendingSystick && priority == systickPriority) {
        return _EXC_SYSTICK;
      }
      if (levelInterrupts != 0) {
        for (var interruptNumber = 0; interruptNumber < 32; interruptNumber++) {
          if (levelInterrupts & (1 << interruptNumber) != 0) {
            return 16 + interruptNumber;
          }
        }
      }
    }
    return 0;
  }

  void setInterrupt(int irq, bool value) {
    // JS shift counts are mod 32
    final irqBit = 1 << (irq & 31);
    if (value && (pendingInterrupts & irqBit) == 0) {
      pendingInterrupts |= irqBit;
      interruptsUpdated = true;
      if (waiting && checkForInterrupts()) {
        waiting = false;
      }
    } else if (!value) {
      pendingInterrupts &= ~irqBit;
    }
  }

  bool checkForInterrupts() {
    /* If we're waiting for an interrupt (i.e. WFI/WFE), the ARM says:
       > If PRIMASK.PM is set to 1, an asynchronous exception that has a higher group priority than any
       > active exception results in a WFI instruction exit. If the group priority of the exception is less than or
       > equal to the execution group priority, the exception is ignored.
    */
    final currentPriority = waiting
        ? PM
              ? exceptionPriority(IPSR)
              : _LOWEST_PRIORITY
        : math.min(exceptionPriority(IPSR), PM ? 0 : _LOWEST_PRIORITY);
    final interruptSet = pendingInterrupts & enabledInterrupts;
    final svCallPriority = this.svCallPriority;
    final systickPriority = this.systickPriority;
    final pendSVPriority = this.pendSVPriority;
    if (pendingNMI) {
      pendingNMI = false;
      exceptionEntry(_EXC_NMI);
      return true;
    }
    for (var priority = 0; priority < currentPriority; priority++) {
      final levelInterrupts = interruptSet & interruptPriorities[priority];
      if (pendingSVCall && priority == svCallPriority) {
        pendingSVCall = false;
        exceptionEntry(_EXC_SVCALL);
        return true;
      }
      if (pendingPendSV && priority == pendSVPriority) {
        pendingPendSV = false;
        exceptionEntry(_EXC_PENDSV);
        return true;
      }
      if (pendingSystick && priority == systickPriority) {
        pendingSystick = false;
        exceptionEntry(_EXC_SYSTICK);
        return true;
      }
      if (levelInterrupts != 0) {
        for (var interruptNumber = 0; interruptNumber < 32; interruptNumber++) {
          if (levelInterrupts & (1 << interruptNumber) != 0) {
            if (interruptNumber > MAX_HARDWARE_IRQ) {
              pendingInterrupts &= ~(1 << interruptNumber);
            }
            exceptionEntry(16 + interruptNumber);
            return true;
          }
        }
      }
    }
    interruptsUpdated = false;
    return false;
  }

  int readSpecialRegister(int sysm) {
    switch (sysm) {
      case _SYSM_APSR:
        return APSR;

      case _SYSM_XPSR:
        return xPSR;

      case _SYSM_IPSR:
        return IPSR;

      case SYSM_PRIMASK:
        return PM ? 1 : 0;

      case SYSM_MSP:
        return SPmain;

      case SYSM_PSP:
        return SPprocess;

      case SYSM_CONTROL:
        return (SPSEL == StackPointerBank.SPprocess ? 2 : 0) | (nPRIV ? 1 : 0);

      default:
        logger.warn(_LOG_NAME, 'MRS with unimplemented SYSm value: $sysm');
        return 0;
    }
  }

  void writeSpecialRegister(int sysm, int value) {
    switch (sysm) {
      case _SYSM_APSR:
        APSR = value;
        break;

      case _SYSM_XPSR:
        xPSR = value;
        break;

      case _SYSM_IPSR:
        IPSR = value;
        break;

      case SYSM_PRIMASK:
        PM = value & 1 != 0;
        interruptsUpdated = true;
        break;

      case SYSM_MSP:
        SPmain = value;
        break;

      case SYSM_PSP:
        SPprocess = value;
        break;

      case SYSM_CONTROL:
        nPRIV = value & 1 != 0;
        if (currentMode == ExecutionMode.Mode_Thread) {
          switchStack(
            value & 2 != 0
                ? StackPointerBank.SPprocess
                : StackPointerBank.SPmain,
          );
        }
        break;

      default:
        logger.warn(_LOG_NAME, 'MRS with unimplemented SYSm value: $sysm');
        return;
    }
  }

  void BXWritePC(int address) {
    if (currentMode == ExecutionMode.Mode_Handler &&
        u32(address) >>> 28 == 0xf) {
      exceptionReturn(address & 0x0fffffff);
    } else {
      PC = address & ~1;
    }
  }

  int _substractUpdateFlags(int minuend, int subtrahend) {
    final result = minuend - subtrahend;
    N = result & 0x80000000 != 0;
    Z = (result & 0xffffffff) == 0;
    C = minuend >= subtrahend;
    V =
        (result & 0x80000000 != 0 &&
            minuend & 0x80000000 == 0 &&
            subtrahend & 0x80000000 != 0) ||
        (result & 0x80000000 == 0 &&
            minuend & 0x80000000 != 0 &&
            subtrahend & 0x80000000 == 0);
    return u32(result);
  }

  int _addUpdateFlags(int addend1, int addend2) {
    final unsignedSum = u32(addend1 + addend2);
    final signedSum = s32(addend1) + s32(addend2);
    final result = addend1 + addend2;
    N = result & 0x80000000 != 0;
    Z = (result & 0xffffffff) == 0;
    C = result == unsignedSum ? false : true;
    V = s32(result) == signedSum ? false : true;
    return result & 0xffffffff;
  }

  int cyclesIO(int addr, [bool write = false]) {
    addr = u32(addr);
    if (addr >= SIO_START_ADDRESS && addr < SIO_START_ADDRESS + 0x10000000) {
      return 0;
    }
    if (addr >= APB_START_ADDRESS && addr < APB_START_ADDRESS + 0x10000000) {
      return write ? 4 : 3;
    }
    return 1;
  }

  int executeInstruction() {
    if (interruptsUpdated) {
      if (checkForInterrupts()) {
        waiting = false;
      }
    }
    // ARM Thumb instruction encoding - 16 bits / 2 bytes
    final opcodePC = PC & ~1; //ensure no LSB set PC are executed
    final opcode = readUint16(opcodePC);
    final wideInstruction = opcode >> 12 == 0xf || opcode >> 11 == 0x1d;
    final opcode2 = wideInstruction ? readUint16(opcodePC + 2) : 0;
    PC += 2;
    var deltaCycles = 1;
    var kind = decodeTable[opcode];
    if (kind == _decodeWide) {
      kind = _decode(opcode, opcode2);
    }
    switch (kind) {
      case 1: // ADCS
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        registers[Rdn] = _addUpdateFlags(
          registers[Rm],
          registers[Rdn] + (C ? 1 : 0),
        );
      case 2: // ADD (register = SP plus immediate)
        final imm8 = opcode & 0xff;
        final Rd = (opcode >> 8) & 0x7;
        registers[Rd] = SP + (imm8 << 2);
      case 3: // ADD (SP plus immediate)
        final imm32 = (opcode & 0x7f) << 2;
        SP += imm32;
      case 4: // ADDS (Encoding T1)
        final imm3 = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        registers[Rd] = _addUpdateFlags(registers[Rn], imm3);
      case 5: // ADDS (Encoding T2)
        final imm8 = opcode & 0xff;
        final Rdn = (opcode >> 8) & 0x7;
        registers[Rdn] = _addUpdateFlags(registers[Rdn], imm8);
      case 6: // ADDS (register)
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        registers[Rd] = _addUpdateFlags(registers[Rn], registers[Rm]);
      case 7: // ADD (register)
        final Rm = (opcode >> 3) & 0xf;
        final Rdn = ((opcode & 0x80) >> 4) | (opcode & 0x7);
        final leftValue = Rdn == _pcRegister ? PC + 2 : registers[Rdn];
        final rightValue = Rm == _pcRegister ? PC + 2 : registers[Rm];
        final result = leftValue + rightValue;
        if (Rdn != _spRegister && Rdn != _pcRegister) {
          registers[Rdn] = result;
        } else if (Rdn == _pcRegister) {
          registers[Rdn] = result & ~0x1;
          deltaCycles++;
        } else if (Rdn == _spRegister) {
          registers[Rdn] = result & ~0x3;
        }
      case 8: // ADR
        final imm8 = opcode & 0xff;
        final Rd = (opcode >> 8) & 0x7;
        registers[Rd] = (opcodePC & 0xfffffffc) + 4 + (imm8 << 2);
      case 9: // ANDS (Encoding T2)
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        final result = registers[Rdn] & registers[Rm];
        registers[Rdn] = result;
        N = result & 0x80000000 != 0;
        Z = (result & 0xffffffff) == 0;
      case 10: // ASRS (immediate)
        final imm5 = (opcode >> 6) & 0x1f;
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        final input = registers[Rm];
        final shiftN = imm5 != 0 ? imm5 : 32;
        final result = shiftN < 32
            ? u32(s32(input) >> shiftN)
            : u32(s32(input & 0x80000000) >> 31);
        registers[Rd] = result;
        N = result & 0x80000000 != 0;
        Z = (result & 0xffffffff) == 0;
        C = input & (1 << (shiftN - 1)) != 0 ? true : false;
      case 11: // ASRS (register)
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        final input = registers[Rdn];
        final shiftN = (registers[Rm] & 0xff) < 32 ? registers[Rm] & 0xff : 32;
        final result = shiftN < 32
            ? u32(s32(input) >> shiftN)
            : u32(s32(input & 0x80000000) >> 31);
        registers[Rdn] = result;
        N = result & 0x80000000 != 0;
        Z = (result & 0xffffffff) == 0;
        // JS shift counts are mod 32: a shift of 0 tests bit 31
        C = input & (1 << ((shiftN - 1) & 31)) != 0 ? true : false;
      case 12: // B (with cond)
        var imm8 = (opcode & 0xff) << 1;
        final cond = (opcode >> 8) & 0xf;
        if (imm8 & (1 << 8) != 0) {
          imm8 = (imm8 & 0x1ff) - 0x200;
        }
        if (checkCondition(cond)) {
          PC += imm8 + 2;
          deltaCycles++;
        }
      case 13: // B
        var imm11 = (opcode & 0x7ff) << 1;
        if (imm11 & (1 << 11) != 0) {
          imm11 = (imm11 & 0x7ff) - 0x800;
        }
        PC += imm11 + 2;
        deltaCycles++;
      case 14: // BICS
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        final result = registers[Rdn] & ~registers[Rm];
        registers[Rdn] = result;
        N = result & 0x80000000 != 0;
        Z = result == 0;
      case 15: // BKPT
        final imm8 = opcode & 0xff;
        breakRewind = 2;
        rp2040.onBreak(imm8);
      case 16: // BL
        final imm11 = opcode2 & 0x7ff;
        final J2 = (opcode2 >> 11) & 0x1;
        final J1 = (opcode2 >> 13) & 0x1;
        final imm10 = opcode & 0x3ff;
        final S = (opcode >> 10) & 0x1;
        final I1 = 1 - (S ^ J1);
        final I2 = 1 - (S ^ J2);
        final imm32 = u32(
          ((S != 0 ? 0xff : 0) << 24) |
              ((I1 << 23) | (I2 << 22) | (imm10 << 12) | (imm11 << 1)),
        );
        LR = (PC + 2) | 0x1;
        PC += 2 + imm32;
        deltaCycles += 2;
        blTaken(this, false);
      case 17: // BLX
        final Rm = (opcode >> 3) & 0xf;
        LR = PC | 0x1;
        PC = registers[Rm] & ~1;
        deltaCycles++;
        blTaken(this, true);
      case 18: // BX
        final Rm = (opcode >> 3) & 0xf;
        BXWritePC(registers[Rm]);
        deltaCycles++;
      case 19: // CMN (register)
        final Rm = (opcode >> 3) & 0x7;
        final Rn = opcode & 0x7;
        _addUpdateFlags(registers[Rn], registers[Rm]);
      case 20: // CMP immediate
        final Rn = (opcode >> 8) & 0x7;
        final imm8 = opcode & 0xff;
        _substractUpdateFlags(registers[Rn], imm8);
      case 21: // CMP (register)
        final Rm = (opcode >> 3) & 0x7;
        final Rn = opcode & 0x7;
        _substractUpdateFlags(registers[Rn], registers[Rm]);
      case 22: // CMP (register) encoding T2
        final Rm = (opcode >> 3) & 0xf;
        final Rn = ((opcode >> 4) & 0x8) | (opcode & 0x7);
        _substractUpdateFlags(registers[Rn], registers[Rm]);
      case 23: // CPSID i
        PM = true;
      case 24: // CPSIE i
        PM = false;
        interruptsUpdated = true;
      case 25: // DMB SY
        PC += 2;
        deltaCycles += 2;
      case 26: // DSB SY
        PC += 2;
        deltaCycles += 2;
      case 27: // EORS
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        final result = registers[Rm] ^ registers[Rdn];
        registers[Rdn] = result;
        N = result & 0x80000000 != 0;
        Z = result == 0;
      case 28: // ISB SY
        PC += 2;
        deltaCycles += 2;
      case 29: // LDMIA
        final Rn = (opcode >> 8) & 0x7;
        final registers = opcode & 0xff;
        var address = this.registers[Rn];
        for (var i = 0; i < 8; i++) {
          if (registers & (1 << i) != 0) {
            this.registers[i] = readUint32(address);
            address += 4;
            deltaCycles++;
          }
        }
        // Write back
        if (registers & (1 << Rn) == 0) {
          this.registers[Rn] = address;
        }
      case 30: // LDR (immediate)
        final imm5 = ((opcode >> 6) & 0x1f) << 2;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final addr = registers[Rn] + imm5;
        deltaCycles += cyclesIO(addr);
        registers[Rt] = readUint32(addr);
      case 31: // LDR (sp + immediate)
        final Rt = (opcode >> 8) & 0x7;
        final imm8 = opcode & 0xff;
        final addr = SP + (imm8 << 2);
        deltaCycles += cyclesIO(addr);
        registers[Rt] = readUint32(addr);
      case 32: // LDR (literal)
        final imm8 = (opcode & 0xff) << 2;
        final Rt = (opcode >> 8) & 7;
        final nextPC = PC + 2;
        final addr = (nextPC & 0xfffffffc) + imm8;
        deltaCycles += cyclesIO(addr);
        registers[Rt] = readUint32(addr);
      case 33: // LDR (register)
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final addr = registers[Rm] + registers[Rn];
        deltaCycles += cyclesIO(addr);
        registers[Rt] = readUint32(addr);
      case 34: // LDRB (immediate)
        final imm5 = (opcode >> 6) & 0x1f;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final addr = registers[Rn] + imm5;
        deltaCycles += cyclesIO(addr);
        registers[Rt] = readUint8(addr);
      case 35: // LDRB (register)
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final addr = registers[Rm] + registers[Rn];
        deltaCycles += cyclesIO(addr);
        registers[Rt] = readUint8(addr);
      case 36: // LDRH (immediate)
        final imm5 = (opcode >> 6) & 0x1f;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final addr = registers[Rn] + (imm5 << 1);
        deltaCycles += cyclesIO(addr);
        registers[Rt] = readUint16(addr);
      case 37: // LDRH (register)
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final addr = registers[Rm] + registers[Rn];
        deltaCycles += cyclesIO(addr);
        registers[Rt] = readUint16(addr);
      case 38: // LDRSB
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final addr = registers[Rm] + registers[Rn];
        deltaCycles += cyclesIO(addr);
        registers[Rt] = _signExtend8(readUint8(addr));
      case 39: // LDRSH
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final addr = registers[Rm] + registers[Rn];
        deltaCycles += cyclesIO(addr);
        registers[Rt] = _signExtend16(readUint16(addr));
      case 40: // LSLS (immediate)
        final imm5 = (opcode >> 6) & 0x1f;
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        final input = registers[Rm];
        final result = u32(input << imm5);
        registers[Rd] = result;
        N = result & 0x80000000 != 0;
        Z = result == 0;
        C = imm5 != 0 ? input & (1 << (32 - imm5)) != 0 : C;
      case 41: // LSLS (register)
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        final input = registers[Rdn];
        final shiftCount = registers[Rm] & 0xff;
        final result = shiftCount >= 32 ? 0 : u32(input << shiftCount);
        registers[Rdn] = result;
        N = result & 0x80000000 != 0;
        Z = result == 0;
        // JS shift counts are mod 32 (a count of 32 tests bit 0)
        C = shiftCount != 0 ? input & (1 << ((32 - shiftCount) & 31)) != 0 : C;
      case 42: // LSRS (immediate)
        final imm5 = (opcode >> 6) & 0x1f;
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        final input = registers[Rm];
        final result = imm5 != 0 ? input >>> imm5 : 0;
        registers[Rd] = result;
        N = result & 0x80000000 != 0;
        Z = result == 0;
        C = (input >>> (imm5 != 0 ? imm5 - 1 : 31)) & 0x1 != 0;
      case 43: // LSRS (register)
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        final shiftAmount = registers[Rm] & 0xff;
        final input = registers[Rdn];
        final result = shiftAmount < 32 ? input >>> shiftAmount : 0;
        registers[Rdn] = result;
        N = result & 0x80000000 != 0;
        Z = result == 0;
        // JS shift counts are mod 32 (a count of 0 tests bit 31)
        C = shiftAmount <= 32
            ? (input >>> ((shiftAmount - 1) & 31)) & 0x1 != 0
            : false;
      case 44: // MOV
        final Rm = (opcode >> 3) & 0xf;
        final Rd = ((opcode >> 4) & 0x8) | (opcode & 0x7);
        var value = Rm == _pcRegister ? PC + 2 : registers[Rm];
        if (Rd == _pcRegister) {
          deltaCycles++;
          value &= ~1;
        } else if (Rd == _spRegister) {
          value &= ~3;
        }
        registers[Rd] = value;
      case 45: // MOVS
        final value = opcode & 0xff;
        final Rd = (opcode >> 8) & 7;
        registers[Rd] = value;
        N = value & 0x80000000 != 0;
        Z = value == 0;
      case 46: // MRS
        final SYSm = opcode2 & 0xff;
        final Rd = (opcode2 >> 8) & 0xf;
        registers[Rd] = readSpecialRegister(SYSm);
        PC += 2;
        deltaCycles += 2;
      case 47: // MSR
        final SYSm = opcode2 & 0xff;
        final Rn = opcode & 0xf;
        writeSpecialRegister(SYSm, registers[Rn]);
        PC += 2;
        deltaCycles += 2;
      case 48: // MULS
        final Rn = (opcode >> 3) & 0x7;
        final Rdm = opcode & 0x7;
        final result = imul(registers[Rn], registers[Rdm]);
        registers[Rdm] = result;
        N = result & 0x80000000 != 0;
        Z = (result & 0xffffffff) == 0;
      case 49: // MVNS
        final Rm = (opcode >> 3) & 7;
        final Rd = opcode & 7;
        final result = u32(~registers[Rm]);
        registers[Rd] = result;
        N = result & 0x80000000 != 0;
        Z = result == 0;
      case 50: // ORRS (Encoding T2)
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        final result = registers[Rdn] | registers[Rm];
        registers[Rdn] = result;
        N = result & 0x80000000 != 0;
        Z = (result & 0xffffffff) == 0;
      case 51: // POP
        final P = (opcode >> 8) & 1;
        var address = SP;
        for (var i = 0; i <= 7; i++) {
          if (opcode & (1 << i) != 0) {
            registers[i] = readUint32(address);
            address += 4;
            deltaCycles++;
          }
        }
        if (P != 0) {
          SP = address + 4;
          BXWritePC(readUint32(address));
          deltaCycles += 2;
        } else {
          SP = address;
        }
      case 52: // PUSH
        var bitCount = 0;
        for (var i = 0; i <= 8; i++) {
          if (opcode & (1 << i) != 0) {
            bitCount++;
          }
        }
        var address = SP - 4 * bitCount;
        for (var i = 0; i <= 7; i++) {
          if (opcode & (1 << i) != 0) {
            writeUint32(address, registers[i]);
            deltaCycles++;
            address += 4;
          }
        }
        if (opcode & (1 << 8) != 0) {
          writeUint32(address, registers[14]);
        }
        SP -= 4 * bitCount;
      case 53: // REV
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        final input = registers[Rm];
        registers[Rd] = u32(
          ((input & 0xff) << 24) |
              (((input >> 8) & 0xff) << 16) |
              (((input >> 16) & 0xff) << 8) |
              ((input >> 24) & 0xff),
        );
      case 54: // REV16
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        final input = registers[Rm];
        registers[Rd] = u32(
          (((input >> 16) & 0xff) << 24) |
              (((input >> 24) & 0xff) << 16) |
              ((input & 0xff) << 8) |
              ((input >> 8) & 0xff),
        );
      case 55: // REVSH
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        final input = registers[Rm];
        registers[Rd] = _signExtend16(
          ((input & 0xff) << 8) | ((input >> 8) & 0xff),
        );
      case 56: // ROR
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        final input = registers[Rdn];
        final shift = (registers[Rm] & 0xff) % 32;
        // JS shift counts are mod 32 (a shift of 0 leaves the input as it is)
        final result = u32((input >>> shift) | (input << ((32 - shift) & 31)));
        registers[Rdn] = result;
        N = result & 0x80000000 != 0;
        Z = result == 0;
        C = result & 0x80000000 != 0;
      case 57: // NEGS / RSBS
        final Rn = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        registers[Rd] = _substractUpdateFlags(0, registers[Rn]);
      case 58: // NOP
      // Do nothing!
      case 59: // SBCS (Encoding T1)
        final Rm = (opcode >> 3) & 0x7;
        final Rdn = opcode & 0x7;
        registers[Rdn] = _substractUpdateFlags(
          registers[Rdn],
          registers[Rm] + (1 - (C ? 1 : 0)),
        );
      case 60: // SEV
        logger.info(_LOG_NAME, 'SEV');
      case 61: // STMIA
        final Rn = (opcode >> 8) & 0x7;
        final registers = opcode & 0xff;
        var address = this.registers[Rn];
        for (var i = 0; i < 8; i++) {
          if (registers & (1 << i) != 0) {
            writeUint32(address, this.registers[i]);
            address += 4;
            deltaCycles++;
          }
        }
        // Write back
        if (registers & (1 << Rn) == 0) {
          this.registers[Rn] = address;
        }
      case 62: // STR (immediate)
        final imm5 = ((opcode >> 6) & 0x1f) << 2;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final address = registers[Rn] + imm5;
        deltaCycles += cyclesIO(address, true);
        writeUint32(address, registers[Rt]);
      case 63: // STR (sp + immediate)
        final Rt = (opcode >> 8) & 0x7;
        final imm8 = opcode & 0xff;
        final address = SP + (imm8 << 2);
        deltaCycles += cyclesIO(address, true);
        writeUint32(address, registers[Rt]);
      case 64: // STR (register)
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final address = registers[Rm] + registers[Rn];
        deltaCycles += cyclesIO(address, true);
        writeUint32(address, registers[Rt]);
      case 65: // STRB (immediate)
        final imm5 = (opcode >> 6) & 0x1f;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final address = registers[Rn] + imm5;
        deltaCycles += cyclesIO(address, true);
        writeUint8(address, registers[Rt]);
      case 66: // STRB (register)
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final address = registers[Rm] + registers[Rn];
        deltaCycles += cyclesIO(address, true);
        writeUint8(address, registers[Rt]);
      case 67: // STRH (immediate)
        final imm5 = ((opcode >> 6) & 0x1f) << 1;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final address = registers[Rn] + imm5;
        deltaCycles += cyclesIO(address, true);
        writeUint16(address, registers[Rt]);
      case 68: // STRH (register)
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rt = opcode & 0x7;
        final address = registers[Rm] + registers[Rn];
        deltaCycles += cyclesIO(address, true);
        writeUint16(address, registers[Rt]);
      case 69: // SUB (SP minus immediate)
        final imm32 = (opcode & 0x7f) << 2;
        SP -= imm32;
      case 70: // SUBS (Encoding T1)
        final imm3 = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        registers[Rd] = _substractUpdateFlags(registers[Rn], imm3);
      case 71: // SUBS (Encoding T2)
        final imm8 = opcode & 0xff;
        final Rdn = (opcode >> 8) & 0x7;
        registers[Rdn] = _substractUpdateFlags(registers[Rdn], imm8);
      case 72: // SUBS (register)
        final Rm = (opcode >> 6) & 0x7;
        final Rn = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        registers[Rd] = _substractUpdateFlags(registers[Rn], registers[Rm]);
      case 73: // SVC
        pendingSVCall = true;
        interruptsUpdated = true;
      case 74: // SXTB
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        registers[Rd] = _signExtend8(registers[Rm]);
      case 75: // SXTH
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        registers[Rd] = _signExtend16(registers[Rm]);
      case 76: // TST
        final Rm = (opcode >> 3) & 0x7;
        final Rn = opcode & 0x7;
        final result = registers[Rn] & registers[Rm];
        N = result & 0x80000000 != 0;
        Z = result == 0;
      case 77: // UDF
        final imm8 = opcode & 0xff;
        breakRewind = 2;
        rp2040.onBreak(imm8);
      case 78: // UDF (Encoding T2)
        final imm4 = opcode & 0xf;
        final imm12 = opcode2 & 0xfff;
        breakRewind = 4;
        rp2040.onBreak((imm4 << 12) | imm12);
        PC += 2;
      case 79: // UXTB
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        registers[Rd] = registers[Rm] & 0xff;
      case 80: // UXTH
        final Rm = (opcode >> 3) & 0x7;
        final Rd = opcode & 0x7;
        registers[Rd] = registers[Rm] & 0xffff;
      case 81: // WFE
        deltaCycles++;
        if (eventRegistered) {
          eventRegistered = false;
        } else {
          waiting = true;
        }
      case 82: // WFI
        deltaCycles++;
        waiting = true;
      case 83: // YIELD
        // do nothing for now. Wait for event!
        logger.info(_LOG_NAME, 'Yield');
      default:
        logger.warn(
          _LOG_NAME,
          'Warning: Instruction at ${opcodePC.toRadixString(16)} is not implemented yet!',
        );
        logger.warn(
          _LOG_NAME,
          'Opcode: 0x${opcode.toRadixString(16)} (0x${opcode2.toRadixString(16)})',
        );
    }

    cycles += deltaCycles;
    return deltaCycles;
  }
}
