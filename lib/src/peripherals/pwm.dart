// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import '../clock/clock.dart';
import '../irq.dart';
import '../utils/timer32.dart';
import 'dma.dart';
import 'peripheral.dart';

/// Control and status register
const _CHn_CSR = 0x00;

/// INT and FRAC form a fixed-point fractional number.
/// Counting rate is system clock frequency divided by this number.
/// Fractional division uses simple 1st-order sigma-delta.
const _CHn_DIV = 0x04;

/// Direct access to the PWM counter
const _CHn_CTR = 0x08;

/// Counter compare values
const _CHn_CC = 0x0c;

/// Counter wrap value
const _CHn_TOP = 0x10;

/// This register aliases the CSR_EN bits for all channels.
/// Writing to this register allows multiple channels to be enabled
/// or disabled simultaneously, so they can run in perfect sync.
/// For each channel, there is only one physical EN register bit,
/// which can be accessed through here or CHx_CSR.
const _EN = 0xa0;

/// Raw Interrupts
const _INTR = 0xa4;

/// Interrupt Enable
const _INTE = 0xa8;

/// Interrupt Force
const _INTF = 0xac;

/// Interrupt status after masking & forcing
const _INTS = 0xb0;

const _INT_MASK = 0xff;

/* CHn_CSR bits */
const _CSR_PH_ADV = 1 << 7;
const _CSR_PH_RET = 1 << 6;
const _CSR_DIVMODE_SHIFT = 4;
const _CSR_DIVMODE_MASK = 0x3;
const _CSR_B_INV = 1 << 3;
const _CSR_A_INV = 1 << 2;
const _CSR_PH_CORRECT = 1 << 1;
const _CSR_EN = 1 << 0;

abstract final class _PWMDivMode {
  static const int FreeRunning = 0;
  static const int BGated = 1;
  static const int BRisingEdge = 2;
  static const int BFallingEdge = 3;
}

class PWMChannel {
  final Timer32 timer;
  late final Timer32PeriodicAlarm alarmA;
  late final Timer32PeriodicAlarm alarmB;
  late final Timer32PeriodicAlarm alarmBottom;

  int csr = 0;
  int div = 0;
  int cc = 0;
  int top = 0;
  bool lastBValue = false;
  bool countingUp = true;
  bool ccUpdated = false;
  bool topUpdated = false;
  // A double: gpioBChanged() subtracts the (fractional) prescaler from it.
  double tickCounter = 0;
  int divMode = _PWMDivMode.FreeRunning;

  // GPIO pin indices: Table 525. Mapping of PWM channels to GPIO pins on RP2040
  final int pinA1;
  final int pinB1;
  final int pinA2;
  final int pinB2;

  final RPPWM _pwm;
  final IClock clock;
  final int index;

  PWMChannel(this._pwm, this.clock, this.index)
    : timer = Timer32(clock, _pwm.clockFreq),
      pinA1 = index * 2,
      pinB1 = index * 2 + 1,
      pinA2 = index < 7 ? 16 + index * 2 : -1,
      pinB2 = index < 7 ? 16 + index * 2 + 1 : -1 {
    alarmA = Timer32PeriodicAlarm(timer, () {
      setA(false);
    });
    alarmB = Timer32PeriodicAlarm(timer, () {
      setB(false);
    });
    alarmBottom = Timer32PeriodicAlarm(timer, () => _wrap());
    alarmA.enable = true;
    alarmB.enable = true;
    alarmBottom.enable = true;
  }

  int readRegister(int offset) {
    switch (offset) {
      case _CHn_CSR:
        return csr;
      case _CHn_DIV:
        return div;
      case _CHn_CTR:
        return timer.counter;
      case _CHn_CC:
        return cc;
      case _CHn_TOP:
        return top;
    }
    /* Shouldn't get here */
    return 0;
  }

  void writeRegister(int offset, int value) {
    switch (offset) {
      case _CHn_CSR:
        if (value & _CSR_EN != 0 && csr & _CSR_EN == 0) {
          _updateDoubleBuffered();
        }
        // PH_ADV and PH_RET are self-clearing, so they never appear in the stored csr value
        csr = value & ~(_CSR_PH_ADV | _CSR_PH_RET);
        if (value & _CSR_EN != 0) {
          if (value & _CSR_PH_ADV != 0) {
            timer.advance(1);
          }
          if (value & _CSR_PH_RET != 0) {
            timer.advance(-1);
          }
        }
        divMode = (csr >> _CSR_DIVMODE_SHIFT) & _CSR_DIVMODE_MASK;
        setBDirection(divMode == _PWMDivMode.FreeRunning);
        updateEnable();
        lastBValue = gpioBValue;
        timer.mode = value & _CSR_PH_CORRECT != 0
            ? TimerMode.ZigZag
            : TimerMode.Increment;
        break;
      case _CHn_DIV:
        {
          div = value & 0x000fffff;
          final intValue = (value >> 4) & 0xff;
          final fracValue = value & 0xf;
          timer.prescaler = (intValue != 0 ? intValue : 256) + fracValue / 16;
          break;
        }
      case _CHn_CTR:
        timer.set(value & 0xffff);
        break;
      case _CHn_CC:
        cc = value;
        ccUpdated = true;
        break;
      case _CHn_TOP:
        top = value & 0xffff;
        topUpdated = true;
        break;
    }
  }

  void reset() {
    writeRegister(_CHn_CSR, 0);
    writeRegister(_CHn_DIV, 0x01 << 4);
    writeRegister(_CHn_CTR, 0);
    writeRegister(_CHn_CC, 0);
    writeRegister(_CHn_TOP, 0xffff);
    countingUp = true;
    timer.enable = false;
    timer.reset();
  }

  void _updateDoubleBuffered() {
    if (ccUpdated) {
      alarmB.target = cc >>> 16;
      alarmA.target = cc & 0xffff;
      ccUpdated = false;
    }
    if (topUpdated) {
      timer.top = top;
      topUpdated = false;
    }
  }

  void _wrap() {
    _pwm.channelInterrupt(index);
    _updateDoubleBuffered();
    if (csr & _CSR_PH_CORRECT == 0) {
      setA(alarmA.target > 0);
      setB(alarmB.target > 0);
    }
  }

  void setA(bool value) {
    if (csr & _CSR_A_INV != 0) {
      value = !value;
    }
    _pwm.gpioSet(pinA1, value);
    if (pinA2 >= 0) {
      _pwm.gpioSet(pinA2, value);
    }
  }

  void setB(bool value) {
    if (csr & _CSR_B_INV != 0) {
      value = !value;
    }
    _pwm.gpioSet(pinB1, value);
    if (pinB2 >= 0) {
      _pwm.gpioSet(pinB2, value);
    }
  }

  bool get gpioBValue {
    return _pwm.gpioRead(pinB1) || (pinB2 > 0 ? _pwm.gpioRead(pinB2) : false);
  }

  void setBDirection(bool value) {
    _pwm.gpioSetDir(pinB1, value);
    if (pinB2 >= 0) {
      _pwm.gpioSetDir(pinB2, value);
    }
  }

  void gpioBChanged() {
    final value = gpioBValue;
    if (value == lastBValue) {
      return;
    }
    lastBValue = value;
    switch (divMode) {
      case _PWMDivMode.BGated:
        updateEnable();
        break;

      case _PWMDivMode.BRisingEdge:
        if (value) {
          tickCounter++;
        }
        break;

      case _PWMDivMode.BFallingEdge:
        if (!value) {
          tickCounter++;
        }
        break;
    }

    if (tickCounter >= timer.prescaler) {
      timer.advance(1);
      tickCounter -= timer.prescaler;
    }
  }

  void updateEnable() {
    final csr = this.csr;
    final divMode = this.divMode;
    final enable = csr & _CSR_EN != 0;
    timer.enable =
        enable &&
        (divMode == _PWMDivMode.FreeRunning ||
            (divMode == _PWMDivMode.BGated && gpioBValue));
  }

  // rp2040js declares only a setter for `en` (no getter).
  set en(int value) {
    if (value != 0 && csr & _CSR_EN == 0) {
      _updateDoubleBuffered();
    }
    if (value != 0) {
      csr |= _CSR_EN;
    } else {
      csr &= ~_CSR_EN;
    }
    updateEnable();
  }
}

class RPPWM extends BasePeripheral implements Peripheral {
  final List<PWMChannel> channels = [];
  int _intRaw = 0;
  int _intEnable = 0;
  int _intForce = 0;

  int gpioValue = 0;
  int gpioDirection = 0;

  RPPWM(super.rp2040, super.name) {
    for (var i = 0; i < 8; i++) {
      channels.add(PWMChannel(this, rp2040.clock, i));
    }
  }

  int get intStatus => (_intRaw & _intEnable) | _intForce;

  @override
  int readUint32(int offset) {
    if (offset < _EN) {
      final channel = offset ~/ 0x14;
      return channels[channel].readRegister(offset % 0x14);
    }
    switch (offset) {
      case _EN:
        // rp2040js ORs `channels[n].en << n`, but PWMChannel has no `en` getter:
        // `undefined << n` is 0, so this register always reads 0 there.
        return 0;
      case _INTR:
        return _intRaw;
      case _INTE:
        return _intEnable;
      case _INTF:
        return _intForce;
      case _INTS:
        return intStatus;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    if (offset < _EN) {
      final channel = offset ~/ 0x14;
      return channels[channel].writeRegister(offset % 0x14, value);
    }

    switch (offset) {
      case _EN:
        channels[7].en = value & (1 << 7);
        channels[6].en = value & (1 << 6);
        channels[5].en = value & (1 << 5);
        channels[4].en = value & (1 << 4);
        channels[3].en = value & (1 << 3);
        channels[2].en = value & (1 << 2);
        channels[1].en = value & (1 << 1);
        channels[0].en = value & (1 << 0);
        break;
      case _INTR:
        _intRaw &= ~(value & _INT_MASK);
        checkInterrupts();
        break;
      case _INTE:
        _intEnable = value & _INT_MASK;
        checkInterrupts();
        break;
      case _INTF:
        _intForce = value & _INT_MASK;
        checkInterrupts();
        break;
      default:
        super.writeUint32(offset, value);
    }
  }

  double get clockFreq => rp2040.clkSys;

  void channelInterrupt(int index) {
    _intRaw |= 1 << index;
    checkInterrupts();

    // We also set the DMA Request (DREQ) for the channel
    rp2040.dma.setDREQ(DREQChannel.DREQ_PWM_WRAP0 + index);
  }

  void checkInterrupts() {
    rp2040.setInterrupt(IRQ.PWM_WRAP, intStatus != 0);
  }

  void gpioSet(int index, bool value) {
    final bit = 1 << index;
    final newGpioValue = value ? gpioValue | bit : gpioValue & ~bit;
    if (gpioValue != newGpioValue) {
      gpioValue = newGpioValue;
      rp2040.gpio[index].checkForUpdates();
    }
  }

  void gpioSetDir(int index, bool output) {
    final bit = 1 << index;
    final newGpioDirection = output
        ? gpioDirection | bit
        : gpioDirection & ~bit;
    if (gpioDirection != newGpioDirection) {
      gpioDirection = newGpioDirection;
      rp2040.gpio[index].checkForUpdates();
    }
  }

  bool gpioRead(int index) {
    return rp2040.gpio[index].inputValue;
  }

  void gpioOnInput(int index) {
    // rp2040js writes `gpioDirection && 1 << index` (a logical, not a bitwise, and);
    // kept as is.
    if (gpioDirection != 0 && 1 << index != 0) {
      return;
    }
    for (final channel in channels) {
      if (channel.pinB1 == index || channel.pinB2 == index) {
        channel.gpioBChanged();
      }
    }
  }

  void reset() {
    gpioDirection = 0xffffffff;
    for (final channel in channels) {
      channel.reset();
    }
  }
}
