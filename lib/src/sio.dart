// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'interpolator.dart';
import 'rp2040.dart';
import 'utils/bit.dart';

const int _CPUID = 0x000;

// GPIO
const int _GPIO_IN = 0x004; // Input value for GPIO pins
const int _GPIO_HI_IN = 0x008; // Input value for QSPI pins
const int _GPIO_OUT = 0x010; // GPIO output value
const int _GPIO_OUT_SET = 0x014; // GPIO output value set
const int _GPIO_OUT_CLR = 0x018; // GPIO output value clear
const int _GPIO_OUT_XOR = 0x01c; // GPIO output value XOR
const int _GPIO_OE = 0x020; // GPIO output enable
const int _GPIO_OE_SET = 0x024; // GPIO output enable set
const int _GPIO_OE_CLR = 0x028; // GPIO output enable clear
const int _GPIO_OE_XOR = 0x02c; // GPIO output enable XOR
const int _GPIO_HI_OUT = 0x030; // QSPI output value
const int _GPIO_HI_OUT_SET = 0x034; // QSPI output value set
const int _GPIO_HI_OUT_CLR = 0x038; // QSPI output value clear
const int _GPIO_HI_OUT_XOR = 0x03c; // QSPI output value XOR
const int _GPIO_HI_OE = 0x040; // QSPI output enable
const int _GPIO_HI_OE_SET = 0x044; // QSPI output enable set
const int _GPIO_HI_OE_CLR = 0x048; // QSPI output enable clear
const int _GPIO_HI_OE_XOR = 0x04c; // QSPI output enable XOR

const int _GPIO_MASK = 0x3fffffff;

//HARDWARE DIVIDER
const int _DIV_UDIVIDEND = 0x060; //  Divider unsigned dividend
const int _DIV_UDIVISOR = 0x064; //  Divider unsigned divisor
const int _DIV_SDIVIDEND = 0x068; //  Divider signed dividend
const int _DIV_SDIVISOR = 0x06c; //  Divider signed divisor
const int _DIV_QUOTIENT = 0x070; //  Divider result quotient
const int _DIV_REMAINDER = 0x074; //Divider result remainder
const int _DIV_CSR = 0x078;

//INTERPOLATOR
const int _INTERP0_ACCUM0 = 0x080; // Read/write access to accumulator 0
const int _INTERP0_ACCUM1 = 0x084; // Read/write access to accumulator 1
const int _INTERP0_BASE0 = 0x088; // Read/write access to BASE0 register
const int _INTERP0_BASE1 = 0x08c; // Read/write access to BASE1 register
const int _INTERP0_BASE2 = 0x090; // Read/write access to BASE2 register
const int _INTERP0_POP_LANE0 =
    0x094; // Read LANE0 result, and simultaneously write lane results to both accumulators (POP)
const int _INTERP0_POP_LANE1 =
    0x098; // Read LANE1 result, and simultaneously write lane results to both accumulators (POP)
const int _INTERP0_POP_FULL =
    0x09c; // Read FULL result, and simultaneously write lane results to both accumulators (POP)
const int _INTERP0_PEEK_LANE0 =
    0x0a0; // Read LANE0 result, without altering any internal state (PEEK)
const int _INTERP0_PEEK_LANE1 =
    0x0a4; // Read LANE1 result, without altering any internal state (PEEK)
const int _INTERP0_PEEK_FULL =
    0x0a8; // Read FULL result, without altering any internal state (PEEK)
const int _INTERP0_CTRL_LANE0 = 0x0ac; // Control register for lane 0
const int _INTERP0_CTRL_LANE1 = 0x0b0; // Control register for lane 1
const int _INTERP0_ACCUM0_ADD =
    0x0b4; // Values written here are atomically added to ACCUM0
const int _INTERP0_ACCUM1_ADD =
    0x0b8; // Values written here are atomically added to ACCUM1
const int _INTERP0_BASE_1AND0 =
    0x0bc; // On write, the lower 16 bits go to BASE0, upper bits to BASE1 simultaneously
const int _INTERP1_ACCUM0 = 0x0c0; // Read/write access to accumulator 0
const int _INTERP1_ACCUM1 = 0x0c4; // Read/write access to accumulator 1
const int _INTERP1_BASE0 = 0x0c8; // Read/write access to BASE0 register
const int _INTERP1_BASE1 = 0x0cc; // Read/write access to BASE1 register
const int _INTERP1_BASE2 = 0x0d0; // Read/write access to BASE2 register
const int _INTERP1_POP_LANE0 =
    0x0d4; // Read LANE0 result, and simultaneously write lane results to both accumulators (POP)
const int _INTERP1_POP_LANE1 =
    0x0d8; // Read LANE1 result, and simultaneously write lane results to both accumulators (POP)
const int _INTERP1_POP_FULL =
    0x0dc; // Read FULL result, and simultaneously write lane results to both accumulators (POP)
const int _INTERP1_PEEK_LANE0 =
    0x0e0; // Read LANE0 result, without altering any internal state (PEEK)
const int _INTERP1_PEEK_LANE1 =
    0x0e4; // Read LANE1 result, without altering any internal state (PEEK)
const int _INTERP1_PEEK_FULL =
    0x0e8; // Read FULL result, without altering any internal state (PEEK)
const int _INTERP1_CTRL_LANE0 = 0x0ec; // Control register for lane 0
const int _INTERP1_CTRL_LANE1 = 0x0f0; // Control register for lane 1
const int _INTERP1_ACCUM0_ADD =
    0x0f4; // Values written here are atomically added to ACCUM0
const int _INTERP1_ACCUM1_ADD =
    0x0f8; // Values written here are atomically added to ACCUM1
const int _INTERP1_BASE_1AND0 =
    0x0fc; // On write, the lower 16 bits go to BASE0, upper bits to BASE1 simultaneously

//SPINLOCK
const int _SPINLOCK_ST = 0x5c;
const int _SPINLOCK0 = 0x100;
const int _SPINLOCK31 = 0x17c;

class RPSIO {
  int gpioValue = 0;
  int gpioOutputEnable = 0;
  int qspiGpioValue = 0;
  int qspiGpioOutputEnable = 0;
  int divDividend = 0;
  int divDivisor = 1;
  int divQuotient = 0;
  int divRemainder = 0;
  int divCSR = 0;
  int spinLock = 0;
  final Interpolator interp0 = Interpolator(0);
  final Interpolator interp1 = Interpolator(1);

  final RP2040 _rp2040;

  RPSIO(this._rp2040);

  void updateHardwareDivider(bool signed) {
    if (divDivisor == 0) {
      // rp2040js compares the dividend as the caller passed it, which is a
      // negative JS number only when a test writes one directly. Here every
      // register value is unsigned, so the signed divider compares it as int32.
      divQuotient = (signed ? s32(divDividend) : divDividend) > 0
          ? 0xffffffff // -1
          : 1;
      divRemainder = divDividend;
    } else {
      // rp2040js divides doubles and lets the Uint32Array register store
      // truncate the quotient; `~/` truncates the same way, and `remainder`
      // keeps the sign of the dividend like JS `%`.
      if (signed) {
        divQuotient = u32(s32(divDividend) ~/ s32(divDivisor));
        divRemainder = u32(s32(divDividend).remainder(s32(divDivisor)));
      } else {
        divQuotient = u32(divDividend) ~/ u32(divDivisor);
        divRemainder = u32(divDividend).remainder(u32(divDivisor));
      }
    }
    divCSR = 0x3;
    _rp2040.core.cycles += 8;
  }

  int readUint32(int offset) {
    if (offset >= _SPINLOCK0 && offset <= _SPINLOCK31) {
      final bitIndexMask = 1 << ((offset - _SPINLOCK0) ~/ 4);
      if (spinLock & bitIndexMask != 0) {
        return 0;
      } else {
        spinLock |= bitIndexMask;
        return bitIndexMask;
      }
    }
    switch (offset) {
      case _GPIO_IN:
        return _rp2040.gpioValues;
      case _GPIO_HI_IN:
        {
          final qspi = _rp2040.qspi;
          var result = 0;
          for (var qspiIndex = 0; qspiIndex < qspi.length; qspiIndex++) {
            if (qspi[qspiIndex].inputValue) {
              result |= 1 << qspiIndex;
            }
          }
          return result;
        }
      case _GPIO_OUT:
        return gpioValue;
      case _GPIO_OE:
        return gpioOutputEnable;
      case _GPIO_HI_OUT:
        return qspiGpioValue;
      case _GPIO_HI_OE:
        return qspiGpioOutputEnable;
      case _GPIO_OUT_SET:
      case _GPIO_OUT_CLR:
      case _GPIO_OUT_XOR:
      case _GPIO_OE_SET:
      case _GPIO_OE_CLR:
      case _GPIO_OE_XOR:
      case _GPIO_HI_OUT_SET:
      case _GPIO_HI_OUT_CLR:
      case _GPIO_HI_OUT_XOR:
      case _GPIO_HI_OE_SET:
      case _GPIO_HI_OE_CLR:
      case _GPIO_HI_OE_XOR:
        return 0; // TODO verify with silicone
      case _CPUID:
        // Returns the current CPU core id (always 0 for now)
        return 0;
      case _SPINLOCK_ST:
        return spinLock;
      case _DIV_UDIVIDEND:
        return divDividend;
      case _DIV_SDIVIDEND:
        return divDividend;
      case _DIV_UDIVISOR:
        return divDivisor;
      case _DIV_SDIVISOR:
        return divDivisor;
      case _DIV_QUOTIENT:
        divCSR &= ~0x2;
        return divQuotient;
      case _DIV_REMAINDER:
        return divRemainder;
      case _DIV_CSR:
        return divCSR;
      case _INTERP0_ACCUM0:
        return interp0.accum0;
      case _INTERP0_ACCUM1:
        return interp0.accum1;
      case _INTERP0_BASE0:
        return interp0.base0;
      case _INTERP0_BASE1:
        return interp0.base1;
      case _INTERP0_BASE2:
        return interp0.base2;
      case _INTERP0_CTRL_LANE0:
        return interp0.ctrl0;
      case _INTERP0_CTRL_LANE1:
        return interp0.ctrl1;
      case _INTERP0_PEEK_LANE0:
        return interp0.result0;
      case _INTERP0_PEEK_LANE1:
        return interp0.result1;
      case _INTERP0_PEEK_FULL:
        return interp0.result2;
      case _INTERP0_POP_LANE0:
        {
          final value = interp0.result0;
          interp0.writeback();
          return value;
        }
      case _INTERP0_POP_LANE1:
        {
          final value = interp0.result1;
          interp0.writeback();
          return value;
        }
      case _INTERP0_POP_FULL:
        {
          final value = interp0.result2;
          interp0.writeback();
          return value;
        }
      case _INTERP0_ACCUM0_ADD:
        return interp0.smresult0;
      case _INTERP0_ACCUM1_ADD:
        return interp0.smresult1;
      case _INTERP1_ACCUM0:
        return interp1.accum0;
      case _INTERP1_ACCUM1:
        return interp1.accum1;
      case _INTERP1_BASE0:
        return interp1.base0;
      case _INTERP1_BASE1:
        return interp1.base1;
      case _INTERP1_BASE2:
        return interp1.base2;
      case _INTERP1_CTRL_LANE0:
        return interp1.ctrl0;
      case _INTERP1_CTRL_LANE1:
        return interp1.ctrl1;
      case _INTERP1_PEEK_LANE0:
        return interp1.result0;
      case _INTERP1_PEEK_LANE1:
        return interp1.result1;
      case _INTERP1_PEEK_FULL:
        return interp1.result2;
      case _INTERP1_POP_LANE0:
        {
          final value = interp1.result0;
          interp1.writeback();
          return value;
        }
      case _INTERP1_POP_LANE1:
        {
          final value = interp1.result1;
          interp1.writeback();
          return value;
        }
      case _INTERP1_POP_FULL:
        {
          final value = interp1.result2;
          interp1.writeback();
          return value;
        }
      case _INTERP1_ACCUM0_ADD:
        return interp1.smresult0;
      case _INTERP1_ACCUM1_ADD:
        return interp1.smresult1;
    }
    _rp2040.logger.warn(
      'SIO',
      'Read from invalid SIO address: ${offset.toRadixString(16)}',
    );
    return 0xffffffff;
  }

  void writeUint32(int offset, int value) {
    if (offset >= _SPINLOCK0 && offset <= _SPINLOCK31) {
      final bitIndexMask = u32(~(1 << ((offset - _SPINLOCK0) ~/ 4)));
      spinLock &= bitIndexMask;
      return;
    }
    final prevGpioValue = gpioValue;
    final prevGpioOutputEnable = gpioOutputEnable;
    switch (offset) {
      case _GPIO_OUT:
        gpioValue = value & _GPIO_MASK;
      case _GPIO_OUT_SET:
        gpioValue |= value & _GPIO_MASK;
      case _GPIO_OUT_CLR:
        gpioValue &= u32(~value);
      case _GPIO_OUT_XOR:
        gpioValue ^= value & _GPIO_MASK;
      case _GPIO_OE:
        gpioOutputEnable = value & _GPIO_MASK;
      case _GPIO_OE_SET:
        gpioOutputEnable |= value & _GPIO_MASK;
      case _GPIO_OE_CLR:
        gpioOutputEnable &= u32(~value);
      case _GPIO_OE_XOR:
        gpioOutputEnable ^= value & _GPIO_MASK;
      case _GPIO_HI_OUT:
        qspiGpioValue = value & _GPIO_MASK;
      case _GPIO_HI_OUT_SET:
        qspiGpioValue |= value & _GPIO_MASK;
      case _GPIO_HI_OUT_CLR:
        qspiGpioValue &= u32(~value);
      case _GPIO_HI_OUT_XOR:
        qspiGpioValue ^= value & _GPIO_MASK;
      case _GPIO_HI_OE:
        qspiGpioOutputEnable = value & _GPIO_MASK;
      case _GPIO_HI_OE_SET:
        qspiGpioOutputEnable |= value & _GPIO_MASK;
      case _GPIO_HI_OE_CLR:
        qspiGpioOutputEnable &= u32(~value);
      case _GPIO_HI_OE_XOR:
        qspiGpioOutputEnable ^= value & _GPIO_MASK;
      case _DIV_UDIVIDEND:
        divDividend = value;
        updateHardwareDivider(false);
      case _DIV_SDIVIDEND:
        divDividend = value;
        updateHardwareDivider(true);
      case _DIV_UDIVISOR:
        divDivisor = value;
        updateHardwareDivider(false);
      case _DIV_SDIVISOR:
        divDivisor = value;
        updateHardwareDivider(true);
      case _DIV_QUOTIENT:
        divQuotient = value;
        divCSR = 0x3;
      case _DIV_REMAINDER:
        divRemainder = value;
        divCSR = 0x3;
      case _INTERP0_ACCUM0:
        interp0.accum0 = value;
        interp0.update();
      case _INTERP0_ACCUM1:
        interp0.accum1 = value;
        interp0.update();
      case _INTERP0_BASE0:
        interp0.base0 = value;
        interp0.update();
      case _INTERP0_BASE1:
        interp0.base1 = value;
        interp0.update();
      case _INTERP0_BASE2:
        interp0.base2 = value;
        interp0.update();
      case _INTERP0_CTRL_LANE0:
        interp0.ctrl0 = value;
        interp0.update();
      case _INTERP0_CTRL_LANE1:
        interp0.ctrl1 = value;
        interp0.update();
      case _INTERP0_ACCUM0_ADD:
        interp0.accum0 = u32(interp0.accum0 + value);
        interp0.update();
      case _INTERP0_ACCUM1_ADD:
        interp0.accum1 = u32(interp0.accum1 + value);
        interp0.update();
      case _INTERP0_BASE_1AND0:
        interp0.setBase01(value);
      case _INTERP1_ACCUM0:
        interp1.accum0 = value;
        interp1.update();
      case _INTERP1_ACCUM1:
        interp1.accum1 = value;
        interp1.update();
      case _INTERP1_BASE0:
        interp1.base0 = value;
        interp1.update();
      case _INTERP1_BASE1:
        interp1.base1 = value;
        interp1.update();
      case _INTERP1_BASE2:
        interp1.base2 = value;
        interp1.update();
      case _INTERP1_CTRL_LANE0:
        interp1.ctrl0 = value;
        interp1.update();
      case _INTERP1_CTRL_LANE1:
        interp1.ctrl1 = value;
        interp1.update();
      case _INTERP1_ACCUM0_ADD:
        interp1.accum0 = u32(interp1.accum0 + value);
        interp1.update();
      case _INTERP1_ACCUM1_ADD:
        interp1.accum1 = u32(interp1.accum1 + value);
        interp1.update();
      case _INTERP1_BASE_1AND0:
        interp1.setBase01(value);
      default:
        _rp2040.logger.warn(
          'SIO',
          'Write to invalid SIO address: ${offset.toRadixString(16)}, value=${value.toRadixString(16)}',
        );
    }
    final pinsToUpdate =
        (gpioValue ^ prevGpioValue) | (gpioOutputEnable ^ prevGpioOutputEnable);
    if (pinsToUpdate != 0) {
      final gpio = _rp2040.gpio;
      for (var gpioIndex = 0; gpioIndex < gpio.length; gpioIndex++) {
        if (pinsToUpdate & (1 << gpioIndex) != 0) {
          gpio[gpioIndex].checkForUpdates();
        }
      }
    }
  }
}
