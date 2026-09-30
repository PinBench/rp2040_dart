// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import '../rp2040.dart';
import '../utils/bit.dart';

const int _ATOMIC_NORMAL = 0;
const int _ATOMIC_XOR = 1;
const int _ATOMIC_SET = 2;
const int _ATOMIC_CLEAR = 3;

int atomicUpdate(int currentValue, int atomicType, int newValue) {
  switch (atomicType) {
    case _ATOMIC_XOR:
      return u32(currentValue ^ newValue);
    case _ATOMIC_SET:
      return u32(currentValue | newValue);
    case _ATOMIC_CLEAR:
      return u32(currentValue & ~newValue);
    default:
      print('Atomic update called with invalid writeType $atomicType');
      return newValue;
  }
}

abstract interface class Peripheral {
  int readUint32(int offset);
  void writeUint32(int offset, int value);
  void writeUint32Atomic(int offset, int value, int atomicType);
}

class BasePeripheral implements Peripheral {
  int rawWriteValue = 0;

  final RP2040 rp2040;
  final String name;

  BasePeripheral(this.rp2040, this.name);

  @override
  int readUint32(int offset) {
    warn('Unimplemented peripheral read from 0x${offset.toRadixString(16)}');
    if (offset > 0x1000) {
      warn('Unimplemented read from peripheral in the atomic operation region');
    }
    return 0xffffffff;
  }

  @override
  void writeUint32(int offset, int value) {
    warn(
      'Unimplemented peripheral write to 0x${offset.toRadixString(16)}: 0x${value.toRadixString(16)}',
    );
  }

  @override
  void writeUint32Atomic(int offset, int value, int atomicType) {
    rawWriteValue = value;
    final newValue = atomicType != _ATOMIC_NORMAL
        ? atomicUpdate(readUint32(offset), atomicType, value)
        : value;
    writeUint32(offset, newValue);
  }

  void debug(String msg) {
    rp2040.logger.debug(name, msg);
  }

  void info(String msg) {
    rp2040.logger.info(name, msg);
  }

  void warn(String msg) {
    rp2040.logger.warn(name, msg);
  }

  void error(String msg) {
    rp2040.logger.error(name, msg);
  }
}

class UnimplementedPeripheral extends BasePeripheral {
  UnimplementedPeripheral(super.rp2040, super.name);
}
