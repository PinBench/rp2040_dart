// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import '../gpio_pin.dart';
import '../utils/bit.dart';
import 'peripheral.dart';

const int _GPIO_CTRL_LAST = 0x0ec;
const int _INTR0 = 0xf0;
const int _PROC0_INTE0 = 0x100;
const int _PROC0_INTF0 = 0x110;
const int _PROC0_INTS0 = 0x120;
const int _PROC0_INTS3 = 0x12c;

class RPIO extends BasePeripheral implements Peripheral {
  RPIO(super.rp2040, super.name);

  ({GPIOPin gpio, bool isCtrl}) getPinFromOffset(int offset) {
    final gpioIndex = offset >>> 3;
    return (gpio: rp2040.gpio[gpioIndex], isCtrl: offset & 0x4 != 0);
  }

  @override
  int readUint32(int offset) {
    if (offset <= _GPIO_CTRL_LAST) {
      final (:gpio, :isCtrl) = getPinFromOffset(offset);
      return isCtrl ? gpio.ctrl : gpio.status;
    }
    if (offset >= _INTR0 && offset <= _PROC0_INTS3) {
      final startIndex = (offset & 0xf) * 2;
      final register = offset & ~0xf;
      final gpio = rp2040.gpio;
      var result = 0;
      for (var index = 7; index >= 0; index--) {
        // rp2040js skips the pins past the end of the array (`gpio[i]` is undefined)
        if (index + startIndex >= gpio.length) {
          continue;
        }
        final pin = gpio[index + startIndex];
        result = u32(result << 4);
        switch (register) {
          case _INTR0:
            result |= pin.irqStatus;
            break;
          case _PROC0_INTE0:
            result |= pin.irqEnableMask;
            break;
          case _PROC0_INTF0:
            result |= pin.irqForceMask;
            break;
          case _PROC0_INTS0:
            result |= (pin.irqStatus & pin.irqEnableMask) | pin.irqForceMask;
            break;
        }
      }
      return result;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    if (offset <= _GPIO_CTRL_LAST) {
      final (:gpio, :isCtrl) = getPinFromOffset(offset);
      if (isCtrl) {
        gpio.ctrl = value;
        gpio.checkForUpdates();
      }
      return;
    }
    if (offset >= _INTR0 && offset <= _PROC0_INTS3) {
      final startIndex = (offset & 0xf) * 2;
      final register = offset & ~0xf;
      final gpio = rp2040.gpio;
      for (var index = 0; index < 8; index++) {
        if (index + startIndex >= gpio.length) {
          continue;
        }
        final pin = gpio[index + startIndex];
        final pinValue = (value >> (index * 4)) & 0xf;
        final pinRawWriteValue = (rawWriteValue >> (index * 4)) & 0xf;
        switch (register) {
          case _INTR0:
            pin.updateIRQValue(pinRawWriteValue);
            break;
          case _PROC0_INTE0:
            if (pin.irqEnableMask != pinValue) {
              pin.irqEnableMask = pinValue;
              rp2040.updateIOInterrupt();
            }
            break;
          case _PROC0_INTF0:
            if (pin.irqForceMask != pinValue) {
              pin.irqForceMask = pinValue;
              rp2040.updateIOInterrupt();
            }
            break;
        }
      }
      return;
    }

    super.writeUint32(offset, value);
  }
}
