// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'peripherals/pio.dart';
import 'rp2040.dart';

enum GPIOPinState {
  Low,
  High,
  Input,
  InputPullUp,
  InputPullDown,
  InputBusKeeper,
}

const int FUNCTION_PWM = 4;
const int FUNCTION_SIO = 5;
const int FUNCTION_PIO0 = 6;
const int FUNCTION_PIO1 = 7;

typedef GPIOPinListener =
    void Function(GPIOPinState state, GPIOPinState oldState);

bool _applyOverride(bool value, int overrideType) {
  switch (overrideType) {
    case 0:
      return value;
    case 1:
      return !value;
    case 2:
      return false;
    case 3:
      return true;
  }
  print('applyOverride received invalid override type $overrideType');
  return value;
}

const int _IRQ_EDGE_HIGH = 1 << 3;
const int _IRQ_EDGE_LOW = 1 << 2;
const int _IRQ_LEVEL_HIGH = 1 << 1;
const int _IRQ_LEVEL_LOW = 1 << 0;

class GPIOPin {
  bool _rawInputValue = false;

  // rp2040js initialises this with `this.value`, evaluated before `ctrl` and
  // `padValue` are assigned (both still undefined): that always gives
  // `GPIOPinState.Input`.
  GPIOPinState _lastValue = GPIOPinState.Input;

  int ctrl = 0x1f;
  int padValue = 0x36; // 0b0110110
  int irqEnableMask = 0;
  int irqForceMask = 0;
  int irqStatus = 0;

  final Set<GPIOPinListener> _listeners = {};

  final RP2040 rp2040;
  final int index;
  final String name;

  GPIOPin(this.rp2040, this.index, [String? name])
    : name = name ?? index.toString();

  bool get rawInterrupt => ((irqStatus & irqEnableMask) | irqForceMask) != 0;

  bool get isSlewFast => padValue & 1 != 0;

  bool get schmittEnabled => padValue & 2 != 0;

  bool get pulldownEnabled => padValue & 4 != 0;

  bool get pullupEnabled => padValue & 8 != 0;

  int get driveStrength => (padValue >> 4) & 0x3;

  bool get inputEnable => padValue & 0x40 != 0;

  bool get outputDisable => padValue & 0x80 != 0;

  int get functionSelect => ctrl & 0x1f;

  int get outputOverride => (ctrl >> 8) & 0x3;

  int get outputEnableOverride => (ctrl >> 12) & 0x3;

  int get inputOverride => (ctrl >> 16) & 0x3;

  int get irqOverride => (ctrl >> 28) & 0x3;

  bool get rawOutputEnable {
    final bitmask = 1 << index;
    switch (functionSelect) {
      case FUNCTION_PWM:
        return rp2040.pwm.gpioDirection & bitmask != 0;

      case FUNCTION_SIO:
        return rp2040.sio.gpioOutputEnable & bitmask != 0;

      case FUNCTION_PIO0:
        return rp2040.pio[0].pinDirections & bitmask != 0;

      case FUNCTION_PIO1:
        return rp2040.pio[1].pinDirections & bitmask != 0;

      default:
        return false;
    }
  }

  bool get rawOutputValue {
    final bitmask = 1 << index;
    switch (functionSelect) {
      case FUNCTION_PWM:
        return rp2040.pwm.gpioValue & bitmask != 0;

      case FUNCTION_SIO:
        return rp2040.sio.gpioValue & bitmask != 0;

      case FUNCTION_PIO0:
        return rp2040.pio[0].pinValues & bitmask != 0;

      case FUNCTION_PIO1:
        return rp2040.pio[1].pinValues & bitmask != 0;

      default:
        return false;
    }
  }

  bool get inputValue =>
      _applyOverride(_rawInputValue && inputEnable, inputOverride);

  bool get irqValue => _applyOverride(rawInterrupt, irqOverride);

  bool get outputEnable =>
      _applyOverride(rawOutputEnable, outputEnableOverride);

  bool get outputValue => _applyOverride(rawOutputValue, outputOverride);

  /// Returns the STATUS register value for the pin, as outlined in section 2.19.6 of the datasheet
  int get status {
    final irqToProc = irqValue ? 1 << 26 : 0;
    final irqFromPad = rawInterrupt ? 1 << 24 : 0;
    final inToPeri = inputValue ? 1 << 19 : 0;
    final inFromPad = _rawInputValue ? 1 << 17 : 0;
    final oeToPad = outputEnable ? 1 << 13 : 0;
    final oeFromPeri = rawOutputEnable ? 1 << 12 : 0;
    final outToPad = outputValue ? 1 << 9 : 0;
    final outFromPeri = rawOutputValue ? 1 << 8 : 0;
    return irqToProc |
        irqFromPad |
        inToPeri |
        inFromPad |
        oeToPad |
        oeFromPeri |
        outToPad |
        outFromPeri;
  }

  GPIOPinState get value {
    if (outputEnable) {
      return outputValue ? GPIOPinState.High : GPIOPinState.Low;
    } else {
      // TODO: check what happens when we enable both pullup/pulldown
      // ANSWER: It is valid, see: 2.19.4.1. Bus Keeper Mode, datasheet p240
      if (pulldownEnabled && pullupEnabled) {
        // Pull high when high, pull low when low:
        return GPIOPinState.InputBusKeeper;
      } else if (pulldownEnabled) {
        return GPIOPinState.InputPullDown;
      } else if (pullupEnabled) {
        return GPIOPinState.InputPullUp;
      }
      return GPIOPinState.Input;
    }
  }

  void setInputValue(bool value) {
    _rawInputValue = value;
    final prevIrqValue = irqValue;
    if (value && inputEnable) {
      irqStatus |= _IRQ_EDGE_HIGH | _IRQ_LEVEL_HIGH;
      irqStatus &= ~_IRQ_LEVEL_LOW;
    } else {
      irqStatus |= _IRQ_EDGE_LOW | _IRQ_LEVEL_LOW;
      irqStatus &= ~_IRQ_LEVEL_HIGH;
    }
    if (irqValue != prevIrqValue) {
      rp2040.updateIOInterrupt();
    }
    if (functionSelect == FUNCTION_PWM) {
      rp2040.pwm.gpioOnInput(index);
    }
    for (final pio in rp2040.pio) {
      for (final machine in pio.machines) {
        if (machine.enabled &&
            machine.waiting &&
            machine.waitType == WaitType.Pin &&
            machine.waitIndex == index) {
          machine.checkWait();
        }
      }
    }
  }

  void checkForUpdates() {
    final lastValue = _lastValue;
    final value = this.value;
    if (value != lastValue) {
      _lastValue = value;
      // A copy, so a listener can remove itself while we iterate.
      for (final listener in _listeners.toList()) {
        listener(value, lastValue);
      }
    }
  }

  void refreshInput() {
    setInputValue(_rawInputValue);
  }

  void updateIRQValue(int value) {
    if (value & _IRQ_EDGE_LOW != 0 && irqStatus & _IRQ_EDGE_LOW != 0) {
      irqStatus &= ~_IRQ_EDGE_LOW;
      rp2040.updateIOInterrupt();
    }
    if (value & _IRQ_EDGE_HIGH != 0 && irqStatus & _IRQ_EDGE_HIGH != 0) {
      irqStatus &= ~_IRQ_EDGE_HIGH;
      rp2040.updateIOInterrupt();
    }
  }

  bool Function() addListener(GPIOPinListener callback) {
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }
}
