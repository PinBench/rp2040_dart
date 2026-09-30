// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// The register map is kept whole, as in rp2040js, including the constants
// this file does not use yet.
// ignore_for_file: unused_element

import '../clock/clock.dart';
import '../irq.dart';
import '../utils/fifo.dart';
import 'dma.dart';
import 'peripheral.dart';

const _CS = 0x00; // ADC Control and Status
const _RESULT = 0x04; // Result of most recent ADC conversion
const _FCS = 0x08; // FIFO control and status
const _FIFO_REG = 0x0c; // Conversion result FIFO
const _DIV = 0x10; // Clock divider.0x14 INTR Raw Interrupts
const _INTR = 0x14; // Raw Interrupts
const _INTE = 0x18; // Interrupt Enable
const _INTF = 0x1c; // Interrupt Force
const _INTS = 0x20; // Interrupt status after masking & forcing

// CS bits
const _CS_RROBIN_MASK = 0x1f;
const _CS_RROBIN_SHIFT = 16;
const _CS_AINSEL_MASK = 0x7;
const _CS_AINSEL_SHIFT = 12;
const _CS_ERR_STICKY = 1 << 10;
const _CS_ERR = 1 << 9;
const _CS_READY = 1 << 8;
const _CS_START_MANY = 1 << 3;
const _CS_START_ONE = 1 << 2;
const _CS_TS_EN = 1 << 1;
const _CS_EN = 1 << 0;
const _CS_WRITE_MASK =
    (_CS_RROBIN_MASK << _CS_RROBIN_SHIFT) |
    (_CS_AINSEL_MASK << _CS_AINSEL_SHIFT) |
    _CS_START_MANY |
    _CS_START_ONE |
    _CS_TS_EN |
    _CS_EN;

// FCS bits
const _FCS_THRES_MASK = 0xf;
const _FCS_THRESH_SHIFT = 24;
const _FCS_LEVEL_MASK = 0xf;
const _FCS_LEVEL_SHIFT = 16;
const _FCS_OVER = 1 << 11;
const _FCS_UNDER = 1 << 10;
const _FCS_FULL = 1 << 9;
const _FCS_EMPTY = 1 << 8;
const _FCS_DREQ_EN = 1 << 3;
const _FCS_ERR = 1 << 2;
const _FCS_SHIFT = 1 << 1;
const _FCS_EN = 1 << 0;
const _FCS_WRITE_MASK =
    (_FCS_THRES_MASK << _FCS_THRESH_SHIFT) |
    _FCS_DREQ_EN |
    _FCS_ERR |
    _FCS_SHIFT |
    _FCS_EN;

// FIFO_REG bits
const _FIFO_ERR = 1 << 15;

// DIV bits
const _DIV_INT_MASK = 0xffff;
const _DIV_INT_SHIFT = 8;
const _DIV_FRAC_MASK = 0xff;
const _DIV_FRAC_SHIFT = 0;

// Interrupt bits
const _FIFO_INT = 1 << 0;

class RPADC extends BasePeripheral implements Peripheral {
  /* Number of ADC channels */
  final int numChannels = 5;

  /// ADC resolution (in bits)
  final int resolution = 12;

  /// Time to read a single sample, in microseconds
  final int sampleTime = 2;

  /// ADC Channel values. Channels 0...3 are connected to GPIO 26...29, and channel 4 is connected to the built-in
  /// temperature sensor: T=27-(ADC_voltage-0.706)/0.001721.
  ///
  /// Changing the values will change the ADC reading, unless you override onADCRead() with a custom implementation.
  final List<int> channelValues = [0, 0, 0, 0, 0];

  /// Invoked whenever the emulated code performs an ADC read.
  ///
  /// The default implementation reads the result from the `channelValues` array, and then calls
  /// completeADCRead() after `sampleTime` microseconds.
  ///
  /// If you override the default implementation, make sure to call `completeADCRead()` after
  /// `sampleTime` microseconds (or else the ADC read will never complete).
  late void Function(int channel) onADCRead = (channel) {
    // Default implementation
    currentChannel = channel;
    sampleAlarm.schedule(sampleTime * 1000.0);
  };

  final FIFO fifo = FIFO(4);
  final int dreq = DREQChannel.DREQ_ADC;

  // Registers
  int cs = 0;
  int fcs = 0;
  int clockDiv = 0;
  int intEnable = 0;
  int intForce = 0;
  int result = 0;

  // Status
  bool busy = false;
  bool err = false;

  int currentChannel = 0;

  /// Used to simulate ADC sample time
  late final IAlarm sampleAlarm;

  /// For scheduling multi-shot ADC capture
  late final IAlarm multiShotAlarm;

  int get temperatueEnable => cs & _CS_TS_EN;

  int get enabled => cs & _CS_EN;

  double get divider =>
      1 +
      ((clockDiv >> _DIV_INT_SHIFT) & _DIV_INT_MASK) +
      ((clockDiv >> _DIV_FRAC_SHIFT) & _DIV_FRAC_MASK) / 256;

  int get intRaw {
    final thres = (fcs >> _FCS_THRESH_SHIFT) & _FCS_THRES_MASK;
    return fifo.itemCount >= thres ? _FIFO_INT : 0;
  }

  int get intStatus => (intRaw & intEnable) | intForce;

  int get _activeChannel => (cs >> _CS_AINSEL_SHIFT) & _CS_AINSEL_MASK;

  set _activeChannel(int channel) {
    cs &= ~(_CS_AINSEL_MASK << _CS_AINSEL_SHIFT);
    // rp2040js masks with CS_AINSEL_SHIFT (12), not CS_AINSEL_MASK; kept as is.
    cs |= (channel & _CS_AINSEL_SHIFT) << _CS_AINSEL_SHIFT;
  }

  RPADC(super.rp2040, super.name) {
    sampleAlarm = rp2040.clock.createAlarm(
      () => completeADCRead(channelValues[currentChannel], false),
    );
    multiShotAlarm = rp2040.clock.createAlarm(() {
      if (cs & _CS_START_MANY != 0) {
        startADCRead();
      }
    });
  }

  void checkInterrupts() {
    rp2040.setInterrupt(IRQ.ADC_FIFO, intStatus != 0);
  }

  void startADCRead() {
    busy = true;
    onADCRead(_activeChannel);
  }

  void _updateDMA() {
    if (fcs & _FCS_DREQ_EN != 0) {
      final thres = (fcs >> _FCS_THRESH_SHIFT) & _FCS_THRES_MASK;
      if (fifo.itemCount >= thres) {
        rp2040.dma.setDREQ(dreq);
      } else {
        rp2040.dma.clearDREQ(dreq);
      }
    }
  }

  void completeADCRead(int value, bool error) {
    busy = false;
    result = value;
    if (error) {
      cs |= _CS_ERR_STICKY | _CS_ERR;
    } else {
      cs &= ~_CS_ERR;
    }

    // FIFO
    if (fcs & _FCS_EN != 0) {
      if (fifo.full) {
        fcs |= _FCS_OVER;
      } else {
        value &= 0xfff; // 12 bits
        if (fcs & _FCS_SHIFT != 0) {
          value >>= 4;
        }
        if (error && fcs & _FCS_ERR != 0) {
          value |= _FIFO_ERR;
        }
        fifo.push(value);
        _updateDMA();
        checkInterrupts();
      }
    }

    // Round-robin
    final round = (cs >> _CS_RROBIN_SHIFT) & _CS_RROBIN_MASK;
    if (round != 0) {
      var channel = _activeChannel + 1;
      while (round & (1 << channel) == 0) {
        channel = (channel + 1) % numChannels;
      }
      _activeChannel = channel;
    }

    // Multi-shot conversions
    if (cs & _CS_START_MANY != 0) {
      const clockMHZ = 48;
      final sampleTicks = clockMHZ * sampleTime;
      if (divider > sampleTicks) {
        // clock runs at 48MHz, subtract 2uS
        final micros = (divider - sampleTicks) / clockMHZ;
        multiShotAlarm.schedule(micros * 1000);
      } else {
        startADCRead();
      }
    }
  }

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _CS:
        return cs | (err ? _CS_ERR : 0) | (busy ? 0 : _CS_READY);
      case _RESULT:
        return result;
      case _FCS:
        return fcs |
            ((fifo.itemCount & _FCS_LEVEL_MASK) << _FCS_LEVEL_SHIFT) |
            (fifo.full ? _FCS_FULL : 0) |
            (fifo.empty ? _FCS_EMPTY : 0);
      case _FIFO_REG:
        if (fifo.empty) {
          fcs |= _FCS_UNDER;
          return 0;
        } else {
          final value = fifo.pull();
          _updateDMA();
          return value;
        }
      case _DIV:
        return clockDiv;
      case _INTR:
        return intRaw;
      case _INTE:
        return intEnable;
      case _INTF:
        return intForce;
      case _INTS:
        return intStatus;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _CS:
        fcs &= ~(value & _CS_ERR_STICKY); // Write-clear bits
        cs = (cs & ~_CS_WRITE_MASK) | (value & _CS_WRITE_MASK);
        if (value & _CS_EN != 0 &&
            !busy &&
            (value & _CS_START_ONE != 0 || value & _CS_START_MANY != 0)) {
          startADCRead();
        }
        break;
      case _FCS:
        fcs &= ~(value & (_FCS_OVER | _FCS_UNDER)); // Write-clear bits
        fcs = (fcs & ~_FCS_WRITE_MASK) | (value & _FCS_WRITE_MASK);
        checkInterrupts();
        break;
      case _DIV:
        clockDiv = value;
        break;
      case _INTE:
        intEnable = value & _FIFO_INT;
        checkInterrupts();
        break;
      case _INTF:
        intForce = value & _FIFO_INT;
        checkInterrupts();
        break;
      default:
        super.writeUint32(offset, value);
    }
  }
}
