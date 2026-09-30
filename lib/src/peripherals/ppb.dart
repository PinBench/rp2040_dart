// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// ignore_for_file: unused_element

import '../irq.dart';
import '../utils/bit.dart';
import '../utils/timer32.dart';
import 'peripheral.dart';

const int CPUID = 0xd00;
const int ICSR = 0xd04;
const int VTOR = 0xd08;
const int SHPR2 = 0xd1c;
const int SHPR3 = 0xd20;

const int _SYST_CSR = 0x010; // SysTick Control and Status Register
const int _SYST_RVR = 0x014; // SysTick Reload Value Register
const int _SYST_CVR = 0x018; // SysTick Current Value Register
const int _SYST_CALIB = 0x01c; // SysTick Calibration Value Register
const int _NVIC_ISER = 0x100; // Interrupt Set-Enable Register
const int _NVIC_ICER = 0x180; // Interrupt Clear-Enable Register
const int _NVIC_ISPR = 0x200; // Interrupt Set-Pending Register
const int _NVIC_ICPR = 0x280; // Interrupt Clear-Pending Register

// Interrupt priority registers:
const int _NVIC_IPR0 = 0x400;
const int _NVIC_IPR1 = 0x404;
const int _NVIC_IPR2 = 0x408;
const int _NVIC_IPR3 = 0x40c;
const int _NVIC_IPR4 = 0x410;
const int _NVIC_IPR5 = 0x414;
const int _NVIC_IPR6 = 0x418;
const int _NVIC_IPR7 = 0x41c;

/// ICSR Bits
const int _NMIPENDSET = 1 << 31;
const int _PENDSVSET = 1 << 28;
const int _PENDSVCLR = 1 << 27;
const int _PENDSTSET = 1 << 26;
const int _PENDSTCLR = 1 << 25;
const int _ISRPREEMPT = 1 << 23;
const int _ISRPENDING = 1 << 22;
const int _VECTPENDING_MASK = 0x1ff;
const int _VECTPENDING_SHIFT = 12;
const int _VECTACTIVE_MASK = 0x1ff;
const int _VECTACTIVE_SHIFT = 0;

/// PPB stands for Private Periphral Bus.
/// These are peripherals that are part of the ARM Cortex Core, and there's one copy for each processor core.
///
/// Included peripheral: NVIC, SysTick timer
class RPPPB extends BasePeripheral implements Peripheral {
  // Systick
  bool systickCountFlag = false;
  bool systickClkSource = false;
  bool systickIntEnable = false;
  int systickReload = 0;
  final Timer32 systickTimer;
  // `late` only because the callback refers to `this`; the constructor body
  // creates it before anything else, where rp2040js's field initialiser does.
  late final Timer32PeriodicAlarm systickAlarm = Timer32PeriodicAlarm(
    systickTimer,
    () {
      systickCountFlag = true;
      if (systickIntEnable) {
        rp2040.core.pendingSystick = true;
        rp2040.core.interruptsUpdated = true;
      }
      systickTimer.set(systickReload);
    },
  );

  RPPPB(super.rp2040, super.name)
    : systickTimer = Timer32(rp2040.clock, rp2040.clkSys) {
    systickAlarm; // create it now, in rp2040js's field-initialisation order
    systickTimer.top = 0xffffff;
    systickTimer.mode = TimerMode.Decrement;
    systickAlarm.target = 0;
    systickAlarm.enable = true;
    reset();
  }

  void reset() {
    writeUint32(_SYST_CSR, 0);
    writeUint32(_SYST_RVR, 0xffffff);
    systickTimer.set(0xffffff);
  }

  @override
  int readUint32(int offset) {
    final rp2040 = this.rp2040;
    final core = rp2040.core;

    switch (offset) {
      case CPUID:
        return 0x410cc601; /* Verified against actual hardware */

      case ICSR:
        {
          final pendingInterrupts =
              core.pendingInterrupts != 0 ||
              core.pendingPendSV ||
              core.pendingSystick ||
              core.pendingSVCall;
          final vectPending = core.vectPending;
          return (core.pendingNMI ? _NMIPENDSET : 0) |
              (core.pendingPendSV ? _PENDSVSET : 0) |
              (core.pendingSystick ? _PENDSTSET : 0) |
              (pendingInterrupts ? _ISRPENDING : 0) |
              (vectPending << _VECTPENDING_SHIFT) |
              ((core.IPSR & _VECTACTIVE_MASK) << _VECTACTIVE_SHIFT);
        }

      case VTOR:
        return core.VTOR;

      /* NVIC */
      case _NVIC_ISPR:
        return u32(core.pendingInterrupts);
      case _NVIC_ICPR:
        return u32(core.pendingInterrupts);
      case _NVIC_ISER:
        return u32(core.enabledInterrupts);
      case _NVIC_ICER:
        return u32(core.enabledInterrupts);

      case _NVIC_IPR0:
      case _NVIC_IPR1:
      case _NVIC_IPR2:
      case _NVIC_IPR3:
      case _NVIC_IPR4:
      case _NVIC_IPR5:
      case _NVIC_IPR6:
      case _NVIC_IPR7:
        {
          final regIndex = (offset - _NVIC_IPR0) >> 2;
          var result = 0;
          for (var byteIndex = 0; byteIndex < 4; byteIndex++) {
            final interruptNumber = regIndex * 4 + byteIndex;
            for (
              var priority = 0;
              priority < core.interruptPriorities.length;
              priority++
            ) {
              if (core.interruptPriorities[priority] & (1 << interruptNumber) !=
                  0) {
                result |= priority << (8 * byteIndex + 6);
              }
            }
          }
          return result;
        }

      case SHPR2:
        return core.SHPR2;
      case SHPR3:
        return core.SHPR3;

      /* SysTick */
      case _SYST_CSR:
        {
          final countFlagValue = systickCountFlag ? 1 << 16 : 0;
          final clkSourceValue = systickClkSource ? 1 << 2 : 0;
          final tickIntValue = systickIntEnable ? 1 << 1 : 0;
          final enableFlagValue = systickTimer.enable ? 1 << 0 : 0;
          systickCountFlag = false;
          return countFlagValue |
              clkSourceValue |
              tickIntValue |
              enableFlagValue;
        }
      case _SYST_CVR:
        return systickTimer.counter;
      case _SYST_RVR:
        return systickReload;
      case _SYST_CALIB:
        return 0x0000270f;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    final rp2040 = this.rp2040;
    final core = rp2040.core;

    const hardwareInterruptMask = (1 << MAX_HARDWARE_IRQ) - 1;

    switch (offset) {
      case ICSR:
        if (value & _NMIPENDSET != 0) {
          core.pendingNMI = true;
          core.interruptsUpdated = true;
        }
        if (value & _PENDSVSET != 0) {
          core.pendingPendSV = true;
          core.interruptsUpdated = true;
        }
        if (value & _PENDSVCLR != 0) {
          core.pendingPendSV = false;
        }
        if (value & _PENDSTSET != 0) {
          core.pendingSystick = true;
          core.interruptsUpdated = true;
        }
        if (value & _PENDSTCLR != 0) {
          core.pendingSystick = false;
        }
        return;

      case VTOR:
        core.VTOR = value;
        return;

      /* NVIC */
      case _NVIC_ISPR:
        core.pendingInterrupts = u32(core.pendingInterrupts | value);
        core.interruptsUpdated = true;
        return;
      case _NVIC_ICPR:
        core.pendingInterrupts = u32(
          core.pendingInterrupts & (~value | hardwareInterruptMask),
        );
        return;
      case _NVIC_ISER:
        core.enabledInterrupts = u32(core.enabledInterrupts | value);
        core.interruptsUpdated = true;
        return;
      case _NVIC_ICER:
        core.enabledInterrupts = u32(core.enabledInterrupts & ~value);
        return;

      case _NVIC_IPR0:
      case _NVIC_IPR1:
      case _NVIC_IPR2:
      case _NVIC_IPR3:
      case _NVIC_IPR4:
      case _NVIC_IPR5:
      case _NVIC_IPR6:
      case _NVIC_IPR7:
        {
          final regIndex = (offset - _NVIC_IPR0) >> 2;
          for (var byteIndex = 0; byteIndex < 4; byteIndex++) {
            final interruptNumber = regIndex * 4 + byteIndex;
            final newPriority = (value >> (8 * byteIndex + 6)) & 0x3;
            for (
              var priority = 0;
              priority < core.interruptPriorities.length;
              priority++
            ) {
              core.interruptPriorities[priority] = u32(
                core.interruptPriorities[priority] & ~(1 << interruptNumber),
              );
            }
            core.interruptPriorities[newPriority] = u32(
              core.interruptPriorities[newPriority] | (1 << interruptNumber),
            );
          }
          core.interruptsUpdated = true;
          return;
        }

      case SHPR2:
        core.SHPR2 = value;
        return;
      case SHPR3:
        core.SHPR3 = value;
        return;

      // SysTick
      case _SYST_CSR:
        systickClkSource = value & (1 << 2) != 0 ? true : false;
        systickIntEnable = value & (1 << 1) != 0 ? true : false;
        systickTimer.enable = value & (1 << 0) != 0 ? true : false;
        return;
      case _SYST_CVR:
        systickTimer.set(0);
        return;
      case _SYST_RVR:
        systickReload = value;
        return;

      default:
        super.writeUint32(offset, value);
    }
  }
}
