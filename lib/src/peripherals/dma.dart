// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// The register map is kept whole, as in rp2040js, including the constants
// this file does not use yet.
// ignore_for_file: unused_element

import '../clock/clock.dart';
import '../irq.dart';
import '../rp2040.dart';
import '../utils/bit.dart';
import 'peripheral.dart';

abstract final class DREQChannel {
  static const int DREQ_PIO0_TX0 = 0;
  static const int DREQ_PIO0_TX1 = 1;
  static const int DREQ_PIO0_TX2 = 2;
  static const int DREQ_PIO0_TX3 = 3;
  static const int DREQ_PIO0_RX0 = 4;
  static const int DREQ_PIO0_RX1 = 5;
  static const int DREQ_PIO0_RX2 = 6;
  static const int DREQ_PIO0_RX3 = 7;
  static const int DREQ_PIO1_TX0 = 8;
  static const int DREQ_PIO1_TX1 = 9;
  static const int DREQ_PIO1_TX2 = 10;
  static const int DREQ_PIO1_TX3 = 11;
  static const int DREQ_PIO1_RX0 = 12;
  static const int DREQ_PIO1_RX1 = 13;
  static const int DREQ_PIO1_RX2 = 14;
  static const int DREQ_PIO1_RX3 = 15;
  static const int DREQ_SPI0_TX = 16;
  static const int DREQ_SPI0_RX = 17;
  static const int DREQ_SPI1_TX = 18;
  static const int DREQ_SPI1_RX = 19;
  static const int DREQ_UART0_TX = 20;
  static const int DREQ_UART0_RX = 21;
  static const int DREQ_UART1_TX = 22;
  static const int DREQ_UART1_RX = 23;
  static const int DREQ_PWM_WRAP0 = 24;
  static const int DREQ_PWM_WRAP1 = 25;
  static const int DREQ_PWM_WRAP2 = 26;
  static const int DREQ_PWM_WRAP3 = 27;
  static const int DREQ_PWM_WRAP4 = 28;
  static const int DREQ_PWM_WRAP5 = 29;
  static const int DREQ_PWM_WRAP6 = 30;
  static const int DREQ_PWM_WRAP7 = 31;
  static const int DREQ_I2C0_TX = 32;
  static const int DREQ_I2C0_RX = 33;
  static const int DREQ_I2C1_TX = 34;
  static const int DREQ_I2C1_RX = 35;
  static const int DREQ_ADC = 36;
  static const int DREQ_XIP_STREAM = 37;
  static const int DREQ_XIP_SSITX = 38;
  static const int DREQ_XIP_SSIRX = 39;
  static const int DREQ_MAX = 40;
}

abstract final class _TREQ {
  static const int Timer0 = 0x3b;
  static const int Timer1 = 0x3c;
  static const int Timer2 = 0x3d;
  static const int Timer3 = 0x3e;
  static const int Permanent = 0x3f;
}

// Per-channel registers
const _CHn_READ_ADDR = 0x000; // DMA Channel n Read Address pointer
const _CHn_WRITE_ADDR = 0x004; // DMA Channel n Write Address pointer
const _CHn_TRANS_COUNT = 0x008; // DMA Channel n Transfer Count
const _CHn_CTRL_TRIG = 0x00c; // DMA Channel n Control and Status
const _CHn_AL1_CTRL = 0x010; // Alias for channel n CTRL register
const _CHn_AL1_READ_ADDR = 0x014; // Alias for channel n READ_ADDR register
const _CHn_AL1_WRITE_ADDR = 0x018; // Alias for channel n WRITE_ADDR register
const _CHn_AL1_TRANS_COUNT_TRIG =
    0x01c; // Alias for channel n TRANS_COUNT register
const _CHn_AL2_CTRL = 0x020; // Alias for channel n CTRL register
const _CHn_AL2_TRANS_COUNT = 0x024; // Alias for channel n TRANS_COUNT register
const _CHn_AL2_READ_ADDR = 0x028; // Alias for channel n READ_ADDR register
const _CHn_AL2_WRITE_ADDR_TRIG =
    0x02c; // Alias for channel n WRITE_ADDR register
const _CHn_AL3_CTRL = 0x030; // Alias for channel n CTRL register
const _CHn_AL3_WRITE_ADDR = 0x034; // Alias for channel n WRITE_ADDR register
const _CHn_AL3_TRANS_COUNT = 0x038; // Alias for channel n TRANS_COUNT register
const _CHn_AL3_READ_ADDR_TRIG = 0x03c; // Alias for channel n READ_ADDR register
const _CHn_DBG_CTDREQ = 0x800;
const _CHn_DBG_TCR = 0x804;
const _CHANNEL_REGISTERS_SIZE = 12 * 0x40;
const _CHANNEL_REGISTERS_MASK = 0x83f;

// General DMA registers
const _INTR = 0x400; // Interrupt Status (raw)
const _INTE0 = 0x404; // Interrupt Enables for IRQ 0
const _INTF0 = 0x408; // Force Interrupts
const _INTS0 = 0x40c; // Interrupt Status for IRQ 0
const _INTE1 = 0x414; // Interrupt Enables for IRQ 1
const _INTF1 = 0x418; // Force Interrupts for IRQ 1
const _INTS1 = 0x41c; // Interrupt Status (masked) for IRQ 1
const _TIMER0 = 0x420; // Pacing (X/Y) Fractional Timer
const _TIMER1 = 0x424; // Pacing (X/Y) Fractional Timer
const _TIMER2 = 0x428; // Pacing (X/Y) Fractional Timer
const _TIMER3 = 0x42c; // Pacing (X/Y) Fractional Timer
const _MULTI_CHAN_TRIGGER =
    0x430; // Trigger one or more channels simultaneously
const _SNIFF_CTRL = 0x434; // Sniffer Control
const _SNIFF_DATA = 0x438; // Data accumulator for sniff hardware
const _FIFO_LEVELS = 0x440; // Debug RAF, WAF, TDF levels
const _CHAN_ABORT =
    0x444; // Abort an in-progress transfer sequence on one or more channels
const _N_CHANNELS = 0x448;

// CHn_CTRL_TRIG bits
const _AHB_ERROR = 0x80000000; // 1 << 31
const _READ_ERROR = 1 << 30;
const _WRITE_ERROR = 1 << 29;
const _BUSY = 1 << 24;
const _SNIFF_EN = 1 << 23;
const _BSWAP = 1 << 22;
const _IRQ_QUIET = 1 << 21;
const _TREQ_SEL_MASK = 0x3f;
const _TREQ_SEL_SHIFT = 15;
const _CHAIN_TO_MASK = 0xf;
const _CHAIN_TO_SHIFT = 11;
const _RING_SEL = 1 << 10;
const _RING_SIZE_MASK = 0xf;
const _RING_SIZE_SHIFT = 6;
const _INCR_WRITE = 1 << 5;
const _INCR_READ = 1 << 4;
const _DATA_SIZE_MASK = 0x3;
const _DATA_SIZE_SHIFT = 2;
const _HIGH_PRIORITY = 1 << 1;
const _EN = 1 << 0;
const _CHn_CTRL_TRIG_WRITE_MASK = 0xffffff;
const _CHn_CTRL_TRIG_WC_MASK = _READ_ERROR | _WRITE_ERROR;

void _noTransfer() {}

class RPDMAChannel {
  int _ctrl = 0;
  int _readAddr = 0;
  int _writeAddr = 0;
  int _transCount = 0;
  int _dreqCounter = 0;
  int _transCountReload = 0;
  int _treqValue = 0;
  int _dataSize = 1;
  int _chainTo = 0;
  int _ringMask = 0;
  void Function() _transferFn = _noTransfer;
  late final IAlarm _transferAlarm;

  final RPDMA dma;
  final RP2040 rp2040;
  final int index;

  RPDMAChannel(this.dma, this.rp2040, this.index) {
    _transferAlarm = rp2040.clock.createAlarm(transfer);
    reset();
  }

  void start() {
    if (_ctrl & _EN == 0 || _ctrl & _BUSY != 0) {
      return;
    }
    _ctrl |= _BUSY;
    _transCount = _transCountReload;
    if (_transCount != 0) {
      scheduleTransfer();
    }
  }

  int get treq => _treqValue;

  bool get active => _ctrl & _EN != 0 && _ctrl & _BUSY != 0;

  void transfer8() {
    final rp2040 = this.rp2040;
    rp2040.writeUint8(_writeAddr, rp2040.readUint8(_readAddr));
  }

  void transfer16() {
    final rp2040 = this.rp2040;
    rp2040.writeUint16(_writeAddr, rp2040.readUint16(_readAddr));
  }

  void transferSwap16() {
    final rp2040 = this.rp2040;
    final input = rp2040.readUint16(_readAddr);
    rp2040.writeUint16(_writeAddr, ((input & 0xff) << 8) | (input >> 8));
  }

  void transfer32() {
    final rp2040 = this.rp2040;
    rp2040.writeUint32(_writeAddr, rp2040.readUint32(_readAddr));
  }

  void transferSwap32() {
    final rp2040 = this.rp2040;
    final input = rp2040.readUint32(_readAddr);
    rp2040.writeUint32(
      _writeAddr,
      u32(
        ((input & 0x000000ff) << 24) |
            ((input & 0x0000ff00) << 8) |
            ((input & 0x00ff0000) >> 8) |
            ((input >> 24) & 0xff),
      ),
    );
  }

  void transfer() {
    final ctrl = _ctrl;
    final dataSize = _dataSize;
    final ringMask = _ringMask;
    _transferFn();
    if (ctrl & _INCR_READ != 0) {
      if (ringMask != 0 && ctrl & _RING_SEL == 0) {
        _readAddr = u32(
          (_readAddr & ~ringMask) | ((_readAddr + dataSize) & ringMask),
        );
      } else {
        _readAddr = u32(_readAddr + dataSize);
      }
    }
    if (ctrl & _INCR_WRITE != 0) {
      if (ringMask != 0 && ctrl & _RING_SEL != 0) {
        _writeAddr = u32(
          (_writeAddr & ~ringMask) | ((_writeAddr + dataSize) & ringMask),
        );
      } else {
        _writeAddr = u32(_writeAddr + dataSize);
      }
    }
    _transCount--;
    if (_transCount > 0) {
      scheduleTransfer();
    } else {
      _ctrl &= ~_BUSY;
      if (_ctrl & _IRQ_QUIET == 0) {
        dma.intRaw |= 1 << index;
        dma.checkInterrupts();
      }
      if (_chainTo != index) {
        // CHAIN_TO can name a channel past the last one: TS's `channels[n]?.start()`
        if (_chainTo < dma.channels.length) {
          dma.channels[_chainTo].start();
        }
      }
    }
  }

  void scheduleTransfer() {
    final dreq = dma.dreq;
    if ((_treqValue < dreq.length && dreq[_treqValue]) ||
        _treqValue == _TREQ.Permanent) {
      _transferAlarm.schedule(0);
    } else {
      final delay = dma.getTimer(_treqValue);
      if (delay != 0) {
        _transferAlarm.schedule(delay * 1000);
      }
    }
  }

  void abort() {
    _ctrl &= ~_BUSY;
    _transferAlarm.cancel();
  }

  int readUint32(int offset) {
    switch (offset) {
      case _CHn_READ_ADDR:
      case _CHn_AL1_READ_ADDR:
      case _CHn_AL2_READ_ADDR:
      case _CHn_AL3_READ_ADDR_TRIG:
        return _readAddr;

      case _CHn_WRITE_ADDR:
      case _CHn_AL1_WRITE_ADDR:
      case _CHn_AL2_WRITE_ADDR_TRIG:
      case _CHn_AL3_WRITE_ADDR:
        return _writeAddr;

      case _CHn_TRANS_COUNT:
      case _CHn_AL1_TRANS_COUNT_TRIG:
      case _CHn_AL2_TRANS_COUNT:
      case _CHn_AL3_TRANS_COUNT:
        return _transCount;

      case _CHn_CTRL_TRIG:
      case _CHn_AL1_CTRL:
      case _CHn_AL2_CTRL:
      case _CHn_AL3_CTRL:
        return _ctrl;

      case _CHn_DBG_CTDREQ:
        return _dreqCounter;

      case _CHn_DBG_TCR:
        return _transCountReload;
    }

    return 0;
  }

  void writeUint32(int offset, int value) {
    switch (offset) {
      case _CHn_READ_ADDR:
      case _CHn_AL1_READ_ADDR:
      case _CHn_AL2_READ_ADDR:
      case _CHn_AL3_READ_ADDR_TRIG:
        _readAddr = value;
        break;

      case _CHn_WRITE_ADDR:
      case _CHn_AL1_WRITE_ADDR:
      case _CHn_AL2_WRITE_ADDR_TRIG:
      case _CHn_AL3_WRITE_ADDR:
        _writeAddr = value;
        break;

      case _CHn_TRANS_COUNT:
      case _CHn_AL1_TRANS_COUNT_TRIG:
      case _CHn_AL2_TRANS_COUNT:
      case _CHn_AL3_TRANS_COUNT:
        _transCountReload = value;
        break;

      case _CHn_CTRL_TRIG:
      case _CHn_AL1_CTRL:
      case _CHn_AL2_CTRL:
      case _CHn_AL3_CTRL:
        {
          _ctrl =
              (_ctrl & ~_CHn_CTRL_TRIG_WRITE_MASK) |
              (value & _CHn_CTRL_TRIG_WRITE_MASK);
          _ctrl &=
              ~(value & _CHn_CTRL_TRIG_WC_MASK); // Handle write-clear (WC) bits
          _treqValue = (_ctrl >> _TREQ_SEL_SHIFT) & _TREQ_SEL_MASK;
          _chainTo = (_ctrl >> _CHAIN_TO_SHIFT) & _CHAIN_TO_MASK;
          final ringSize = (_ctrl >> _RING_SIZE_SHIFT) & _RING_SIZE_MASK;
          _ringMask = ringSize != 0 ? (1 << ringSize) - 1 : 0;
          switch ((_ctrl >> _DATA_SIZE_SHIFT) & _DATA_SIZE_MASK) {
            case 1:
              _dataSize = 2;
              _transferFn = _ctrl & _BSWAP != 0 ? transferSwap16 : transfer16;
              break;
            case 2:
              _dataSize = 4;
              _transferFn = _ctrl & _BSWAP != 0 ? transferSwap32 : transfer32;
              break;
            case 0:
            default:
              _transferFn = transfer8;
              _dataSize = 1;
          }
          if (_ctrl & _EN != 0 && _ctrl & _BUSY != 0) {
            scheduleTransfer();
          }
          if (_ctrl & _EN == 0) {
            _transferAlarm.cancel();
          }
          break;
        }

      case _CHn_DBG_CTDREQ:
        _dreqCounter = 0;
        break;
    }

    if (offset == _CHn_AL3_READ_ADDR_TRIG ||
        offset == _CHn_AL2_WRITE_ADDR_TRIG ||
        offset == _CHn_AL1_TRANS_COUNT_TRIG ||
        offset == _CHn_CTRL_TRIG) {
      if (value != 0) {
        start();
      } else if (_ctrl & _IRQ_QUIET != 0) {
        // Null trigger interrupts
        dma.intRaw |= 1 << index;
        dma.checkInterrupts();
      }
    }
  }

  void reset() {
    writeUint32(_CHn_CTRL_TRIG, index << _CHAIN_TO_SHIFT);
  }
}

class RPDMA extends BasePeripheral implements Peripheral {
  final List<RPDMAChannel> channels = [];

  int intRaw = 0;
  int _intEnable0 = 0;
  int _intForce0 = 0;
  int _intEnable1 = 0;
  int _intForce1 = 0;
  int _timer0 = 0;
  int _timer1 = 0;
  int _timer2 = 0;
  int _timer3 = 0;

  // TS `Array(DREQ_MAX)` starts out holding `undefined`, which reads as false.
  final List<bool> dreq = List<bool>.filled(DREQChannel.DREQ_MAX, false);

  RPDMA(super.rp2040, super.name) {
    for (var i = 0; i < 12; i++) {
      channels.add(RPDMAChannel(this, rp2040, i));
    }
  }

  int get intStatus0 => (intRaw & _intEnable0) | _intForce0;

  int get intStatus1 => (intRaw & _intEnable1) | _intForce1;

  @override
  int readUint32(int offset) {
    if ((offset & 0x7ff) < _CHANNEL_REGISTERS_SIZE) {
      final channelIndex = (offset & 0x7ff) >> 6;
      return channels[channelIndex].readUint32(
        offset & _CHANNEL_REGISTERS_MASK,
      );
    }
    switch (offset) {
      case _TIMER0:
        return _timer0;
      case _TIMER1:
        return _timer1;
      case _TIMER2:
        return _timer2;
      case _TIMER3:
        return _timer3;
      case _INTR:
        return intRaw;
      case _INTE0:
        return _intEnable0;
      case _INTF0:
        return _intForce0;
      case _INTS0:
        return intStatus0;
      case _INTE1:
        return _intEnable1;
      case _INTF1:
        return _intForce1;
      case _INTS1:
        return intStatus1;
      case _N_CHANNELS:
        return channels.length;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    if ((offset & 0x7ff) < _CHANNEL_REGISTERS_SIZE) {
      final channelIndex = (offset & 0x7ff) >> 6;
      channels[channelIndex].writeUint32(
        offset & _CHANNEL_REGISTERS_MASK,
        value,
      );
      return;
    }
    switch (offset) {
      case _TIMER0:
        _timer0 = value;
        return;
      case _TIMER1:
        _timer1 = value;
        return;
      case _TIMER2:
        _timer2 = value;
        return;
      case _TIMER3:
        _timer3 = value;
        return;
      case _INTR:
      case _INTS0:
      case _INTS1:
        intRaw &= ~rawWriteValue;
        checkInterrupts();
        return;
      case _INTE0:
        _intEnable0 = value & 0xffff;
        checkInterrupts();
        return;
      case _INTF0:
        _intForce0 = value & 0xffff;
        checkInterrupts();
        return;
      case _INTE1:
        _intEnable1 = value & 0xffff;
        checkInterrupts();
        return;
      case _INTF1:
        _intForce1 = value & 0xffff;
        checkInterrupts();
        return;
      case _MULTI_CHAN_TRIGGER:
        for (final chan in channels) {
          if (value & (1 << chan.index) != 0) {
            chan.start();
          }
        }
        return;
      case _CHAN_ABORT:
        for (final chan in channels) {
          if (value & (1 << chan.index) != 0) {
            chan.abort();
          }
        }
        return;
      default:
        super.writeUint32(offset, value);
    }
  }

  void setDREQ(int dreqChannel) {
    final dreq = this.dreq;
    if (!dreq[dreqChannel]) {
      dreq[dreqChannel] = true;
      for (final channel in channels) {
        if (channel.treq == dreqChannel && channel.active) {
          channel.scheduleTransfer();
        }
      }
    }
  }

  void clearDREQ(int dreqChannel) {
    dreq[dreqChannel] = false;
  }

  /// Returns the number of microseconds for a cycle of the given DMA timer, or 0 if the timer is disabled.
  double getTimer(int treq) {
    var dividend = 0, divisor = 1;
    switch (treq) {
      case _TREQ.Permanent:
        dividend = 1;
        divisor = 1;
        break;
      case _TREQ.Timer0:
        dividend = _timer0 >>> 16;
        divisor = _timer0 & 0xffff;
        break;
      case _TREQ.Timer1:
        dividend = _timer1 >>> 16;
        divisor = _timer1 & 0xffff;
        break;
      case _TREQ.Timer2:
        dividend = _timer2 >>> 16;
        divisor = _timer2 & 0xffff;
        break;
      case _TREQ.Timer3:
        // rp2040js writes `>>> 36`, which JS takes mod 32: a shift by 4.
        dividend = _timer3 >>> (36 & 31);
        divisor = _timer3 & 0xffff;
        break;
    }
    if (divisor == 0) {
      return 0;
    }
    return ((dividend / divisor) * 1e6) / rp2040.clkSys;
  }

  void checkInterrupts() {
    rp2040.setInterrupt(IRQ.DMA_IRQ0, intStatus0 != 0);
    rp2040.setInterrupt(IRQ.DMA_IRQ1, intStatus1 != 0);
  }
}
