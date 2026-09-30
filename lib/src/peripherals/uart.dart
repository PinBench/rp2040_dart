// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// ignore_for_file: unused_element

import '../utils/fifo.dart';
import 'peripheral.dart';

const int _UARTDR = 0x0;
const int _UARTFR = 0x18;
const int _UARTIBRD = 0x24;
const int _UARTFBRD = 0x28;
const int _UARTLCR_H = 0x2c;
const int _UARTCR = 0x30;
const int _UARTIMSC = 0x38;
const int _UARTIRIS = 0x3c;
const int _UARTIMIS = 0x40;
const int _UARTICR = 0x44;
const int _UARTPERIPHID0 = 0xfe0;
const int _UARTPERIPHID1 = 0xfe4;
const int _UARTPERIPHID2 = 0xfe8;
const int _UARTPERIPHID3 = 0xfec;
const int _UARTPCELLID0 = 0xff0;
const int _UARTPCELLID1 = 0xff4;
const int _UARTPCELLID2 = 0xff8;
const int _UARTPCELLID3 = 0xffc;

// UARTFR bits:
const int _TXFE = 1 << 7;
const int _RXFF = 1 << 6;
const int _RXFE = 1 << 4;

// UARTLCR_H bits:
const int _FEN = 1 << 4;

// UARTCR bits:
const int _RXE = 1 << 9;
const int _TXE = 1 << 8;
const int _UARTEN = 1 << 0;

// Interrupt bits
const int _UARTTXINTR = 1 << 5;
const int _UARTRXINTR = 1 << 4;

class IUARTDMAChannels {
  /// A `DREQChannel` value.
  final int rx;

  /// A `DREQChannel` value.
  final int tx;

  const IUARTDMAChannels({required this.rx, required this.tx});
}

class RPUART extends BasePeripheral implements Peripheral {
  int _ctrlRegister = _RXE | _TXE;
  int _lineCtrlRegister = 0;
  final FIFO _rxFIFO = FIFO(32);
  int _interruptMask = 0;
  int _interruptStatus = 0;
  int _intDivisor = 0;
  int _fracDivisor = 0;

  void Function(int value)? onByte;
  void Function(int baudRate)? onBaudRateChange;

  final int irq;
  final IUARTDMAChannels dreq;

  RPUART(super.rp2040, super.name, this.irq, this.dreq);

  bool get enabled => _ctrlRegister & _UARTEN != 0;

  bool get txEnabled => _ctrlRegister & _TXE != 0;

  bool get rxEnabled => _ctrlRegister & _RXE != 0;

  bool get fifosEnabled => _lineCtrlRegister & _FEN != 0;

  /// Number of bits per UART character
  int get wordLength {
    switch ((_lineCtrlRegister >>> 5) & 0x3) {
      case 0x0:
        return 5;
      case 0x1:
        return 6;
      case 0x2:
        return 7;
      default: // 0b11
        return 8;
    }
  }

  double get baudDivider => _intDivisor + _fracDivisor / 64;

  /// Dart port note: rp2040js returns `Infinity` while the divider is 0,
  /// which is no Dart `int`; this returns 0 then.
  int get baudRate {
    final baudDivider = this.baudDivider;
    if (baudDivider == 0) {
      return 0;
    }
    return (rp2040.clkPeri / (baudDivider * 16)).round();
  }

  /// Re-reports the baud rate, unless the firmware has not set the divider yet.
  void clkPeriChanged() {
    if (baudDivider != 0) {
      onBaudRateChange?.call(baudRate);
    }
  }

  int get flags =>
      (_rxFIFO.full ? _RXFF : 0) | (_rxFIFO.empty ? _RXFE : 0) | _TXFE;

  void checkInterrupts() {
    // TODO We should actually implement a proper FIFO for TX
    _interruptStatus |= _UARTTXINTR;
    rp2040.setInterrupt(irq, _interruptStatus & _interruptMask != 0);
  }

  void feedByte(int value) {
    _rxFIFO.push(value);
    // TODO check if the FIFO has reached the threshold level
    _interruptStatus |= _UARTRXINTR;
    checkInterrupts();
  }

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _UARTDR:
        {
          final value = _rxFIFO.pull();
          if (!_rxFIFO.empty) {
            _interruptStatus |= _UARTRXINTR;
          } else {
            _interruptStatus &= ~_UARTRXINTR;
          }
          checkInterrupts();
          return value;
        }
      case _UARTFR:
        return flags;
      case _UARTIBRD:
        return _intDivisor;
      case _UARTFBRD:
        return _fracDivisor;
      case _UARTLCR_H:
        return _lineCtrlRegister;
      case _UARTCR:
        return _ctrlRegister;
      case _UARTIMSC:
        return _interruptMask;
      case _UARTIRIS:
        return _interruptStatus;
      case _UARTIMIS:
        return _interruptStatus & _interruptMask;
      case _UARTPERIPHID0:
        return 0x11;
      case _UARTPERIPHID1:
        return 0x10;
      case _UARTPERIPHID2:
        return 0x34;
      case _UARTPERIPHID3:
        return 0x00;
      case _UARTPCELLID0:
        return 0x0d;
      case _UARTPCELLID1:
        return 0xf0;
      case _UARTPCELLID2:
        return 0x05;
      case _UARTPCELLID3:
        return 0xb1;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _UARTDR:
        onByte?.call(value & 0xff);

      case _UARTIBRD:
        _intDivisor = value & 0xffff;
        onBaudRateChange?.call(baudRate);

      case _UARTFBRD:
        _fracDivisor = value & 0x3f;
        onBaudRateChange?.call(baudRate);

      case _UARTLCR_H:
        _lineCtrlRegister = value;

      case _UARTCR:
        _ctrlRegister = value;
        if (enabled) {
          rp2040.dma.setDREQ(dreq.tx);
        } else {
          rp2040.dma.clearDREQ(dreq.tx);
        }

      case _UARTIMSC:
        _interruptMask = value & 0x7ff;
        checkInterrupts();

      case _UARTICR:
        _interruptStatus &= ~rawWriteValue;
        checkInterrupts();

      default:
        super.writeUint32(offset, value);
    }
  }
}
