// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import '../gpio_pin.dart';
import 'peripheral.dart';

const int _VOLTAGE_SELECT = 0;
const int _GPIO_FIRST = 0x4;
const int _GPIO_LAST = 0x78;

const int _QSPI_FIRST = 0x4;
const int _QSPI_LAST = 0x18;

/// rp2040js's `IIOBank`: `'qspi'` or `'bank0'`.
typedef IIOBank = String;

class RPPADS extends BasePeripheral implements Peripheral {
  int voltageSelect = 0;

  final int _firstPadRegister;
  final int _lastPadRegister;

  final IIOBank bank;

  RPPADS(super.rp2040, super.name, this.bank)
    : _firstPadRegister = bank == 'qspi' ? _QSPI_FIRST : _GPIO_FIRST,
      _lastPadRegister = bank == 'qspi' ? _QSPI_LAST : _GPIO_LAST;

  GPIOPin getPinFromOffset(int offset) {
    final gpioIndex = (offset - _firstPadRegister) >>> 2;
    if (bank == 'qspi') {
      return rp2040.qspi[gpioIndex];
    } else {
      return rp2040.gpio[gpioIndex];
    }
  }

  @override
  int readUint32(int offset) {
    if (offset >= _firstPadRegister && offset <= _lastPadRegister) {
      final gpio = getPinFromOffset(offset);
      return gpio.padValue;
    }
    switch (offset) {
      case _VOLTAGE_SELECT:
        return voltageSelect;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    if (offset >= _firstPadRegister && offset <= _lastPadRegister) {
      final gpio = getPinFromOffset(offset);
      final oldInputEnable = gpio.inputEnable;
      gpio.padValue = value;
      gpio.checkForUpdates();
      if (oldInputEnable != gpio.inputEnable) {
        gpio.refreshInput();
      }
      return;
    }
    switch (offset) {
      case _VOLTAGE_SELECT:
        voltageSelect = value & 1;
        break;
      default:
        super.writeUint32(offset, value);
    }
  }
}
