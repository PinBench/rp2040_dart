// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// ignore_for_file: unused_element

import '../utils/fifo.dart';
import 'peripheral.dart';

const int _SSPCR0 = 0x000; // Control register 0, SSPCR0 on page 3-4
const int _SSPCR1 = 0x004; // Control register 1, SSPCR1 on page 3-5
const int _SSPDR = 0x008; // Data register, SSPDR on page 3-6
const int _SSPSR = 0x00c; // Status register, SSPSR on page 3-7
const int _SSPCPSR = 0x010; // Clock prescale register, SSPCPSR on page 3-8
const int _SSPIMSC =
    0x014; // Interrupt mask set or clear register, SSPIMSC on page 3-9
const int _SSPRIS = 0x018; // Raw interrupt status register, SSPRIS on page 3-10
const int _SSPMIS =
    0x01c; // Masked interrupt status register, SSPMIS on page 3-11
const int _SSPICR = 0x020; // Interrupt clear register, SSPICR on page 3-11
const int _SSPDMACR = 0x024; // DMA control register, SSPDMACR on page 3-12
const int _SSPPERIPHID0 =
    0xfe0; // Peripheral identification registers, SSPPeriphID0-3 on page 3-13
const int _SSPPERIPHID1 =
    0xfe4; // Peripheral identification registers, SSPPeriphID0-3 on page 3-13
const int _SSPPERIPHID2 =
    0xfe8; // Peripheral identification registers, SSPPeriphID0-3 on page 3-13
const int _SSPPERIPHID3 =
    0xfec; // Peripheral identification registers, SSPPeriphID0-3 on page 3-13
const int _SSPPCELLID0 =
    0xff0; // PrimeCell identification registers, SSPPCellID0-3 on page 3-16
const int _SSPPCELLID1 =
    0xff4; // PrimeCell identification registers, SSPPCellID0-3 on page 3-16
const int _SSPPCELLID2 =
    0xff8; // PrimeCell identification registers, SSPPCellID0-3 on page 3-16
const int _SSPPCELLID3 =
    0xffc; // PrimeCell identification registers, SSPPCellID0-3 on page 3-16

// SSPCR0 bits:
const int _SCR_MASK = 0xff;
const int _SCR_SHIFT = 8;
const int _SPH = 1 << 7;
const int _SPO = 1 << 6;
const int _FRF_MASK = 0x3;
const int _FRF_SHIFT = 4;
const int _DSS_MASK = 0xf;
const int _DSS_SHIFT = 0;

// SSPCR1 bits:
const int _SOD = 1 << 3;
const int _MS = 1 << 2;
const int _SSE = 1 << 1;
const int _LBM = 1 << 0;

// SSPSR bits:
const int _BSY = 1 << 4;
const int _RFF = 1 << 3;
const int _RNE = 1 << 2;
const int _TNF = 1 << 1;
const int _TFE = 1 << 0;

// SSPCPSR bits:
const int _CPSDVSR_MASK = 0xfe;
const int _CPSDVSR_SHIFT = 0;

// SSPDMACR bits:
const int _TXDMAE = 1 << 1;
const int _RXDMAE = 1 << 0;

// Interrupts:
const int _SSPTXINTR = 1 << 3;
const int _SSPRXINTR = 1 << 2;
const int _SSPRTINTR = 1 << 1;
const int _SSPRORINTR = 1 << 0;

class ISPIDMAChannels {
  /// A `DREQChannel` value.
  final int rx;

  /// A `DREQChannel` value.
  final int tx;

  const ISPIDMAChannels({required this.rx, required this.tx});
}

class RPSPI extends BasePeripheral implements Peripheral {
  final FIFO rxFIFO = FIFO(8);
  final FIFO txFIFO = FIFO(8);

  // User provided callbacks
  // (`late` only because the default refers to `this`.)
  late void Function(int value) onTransmit = (_) => completeTransmit(0);

  bool _busy = false;
  int _control0 = 0;
  int _control1 = 0;
  int _dmaControl = 0;
  int _clockDivisor = 0;
  int _intRaw = 0;
  int _intEnable = 0;

  int get intStatus => _intRaw & _intEnable;

  bool get enabled => _control1 & _SSE != 0;

  /// Data size in bits: 4 to 16 bits
  int get dataBits => ((_control0 >> _DSS_SHIFT) & _DSS_MASK) + 1;

  bool get masterMode => !(_control0 & _MS != 0);

  int get spiMode {
    final cpol = _control0 & _SPO;
    final cpha = _control0 & _SPH;
    return cpol != 0
        ? (cpha != 0 ? 2 : 3)
        : cpha != 0
        ? 1
        : 0;
  }

  double get clockFrequency {
    if (_clockDivisor == 0) {
      return 0;
    }

    final scr = (_control0 >> _SCR_SHIFT) & _SCR_MASK;
    return rp2040.clkPeri / (_clockDivisor * (1 + scr));
  }

  void _updateDMATx() {
    if (txFIFO.full) {
      rp2040.dma.clearDREQ(dreq.tx);
    } else {
      rp2040.dma.setDREQ(dreq.tx);
    }
  }

  void _updateDMARx() {
    if (rxFIFO.empty) {
      rp2040.dma.clearDREQ(dreq.rx);
    } else {
      rp2040.dma.setDREQ(dreq.rx);
    }
  }

  final int irq;
  final ISPIDMAChannels dreq;

  RPSPI(super.rp2040, super.name, this.irq, this.dreq) {
    _updateDMATx();
    _updateDMARx();
  }

  void _doTX() {
    if (!_busy && !txFIFO.empty) {
      final value = txFIFO.pull();
      _busy = true;
      onTransmit(value);
      _fifosUpdated();
    }
  }

  void completeTransmit(int rxValue) {
    _busy = false;
    if (!rxFIFO.full) {
      rxFIFO.push(rxValue);
    } else {
      _intRaw |= _SSPRORINTR;
    }
    _fifosUpdated();
    _doTX();
  }

  void checkInterrupts() {
    rp2040.setInterrupt(irq, intStatus != 0);
  }

  void _fifosUpdated() {
    final prevStatus = intStatus;
    if (txFIFO.itemCount <= txFIFO.size / 2) {
      _intRaw |= _SSPTXINTR;
    } else {
      _intRaw &= ~_SSPTXINTR;
    }
    if (rxFIFO.itemCount >= rxFIFO.size / 2) {
      _intRaw |= _SSPRXINTR;
    } else {
      _intRaw &= ~_SSPRXINTR;
    }
    if (intStatus != prevStatus) {
      checkInterrupts();
    }

    _updateDMATx();
    _updateDMARx();
  }

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _SSPCR0:
        return _control0;
      case _SSPCR1:
        return _control1;
      case _SSPDR:
        if (!rxFIFO.empty) {
          final value = rxFIFO.pull();
          _fifosUpdated();
          return value;
        }
        return 0;
      case _SSPSR:
        return (_busy || !txFIFO.empty ? _BSY : 0) |
            (rxFIFO.full ? _RFF : 0) |
            (!rxFIFO.empty ? _RNE : 0) |
            (!txFIFO.full ? _TNF : 0) |
            (txFIFO.empty ? _TFE : 0);
      case _SSPCPSR:
        return _clockDivisor;
      case _SSPIMSC:
        return _intEnable;
      case _SSPRIS:
        return _intRaw;
      case _SSPMIS:
        return intStatus;
      case _SSPDMACR:
        return _dmaControl;
      case _SSPPERIPHID0:
        return 0x22;
      case _SSPPERIPHID1:
        return 0x10;
      case _SSPPERIPHID2:
        return 0x34;
      case _SSPPERIPHID3:
        return 0x00;
      case _SSPPCELLID0:
        return 0x0d;
      case _SSPPCELLID1:
        return 0xf0;
      case _SSPPCELLID2:
        return 0x05;
      case _SSPPCELLID3:
        return 0xb1;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _SSPCR0:
        _control0 = value;
        return;
      case _SSPCR1:
        _control1 = value;
        return;
      case _SSPDR:
        if (!txFIFO.full) {
          // decoded with respect to SSPCR0.DSS
          txFIFO.push(value & ((1 << dataBits) - 1));
          _doTX();
          _fifosUpdated();
        }
        return;
      case _SSPCPSR:
        _clockDivisor = value & _CPSDVSR_MASK;
        return;
      case _SSPIMSC:
        _intEnable = value;
        checkInterrupts();
        return;
      case _SSPDMACR:
        _dmaControl = value;
        return;
      case _SSPICR:
        _intRaw &= ~(value & (_SSPRTINTR | _SSPRORINTR));
        checkInterrupts();
        return;
      default:
        super.writeUint32(offset, value);
    }
  }
}
