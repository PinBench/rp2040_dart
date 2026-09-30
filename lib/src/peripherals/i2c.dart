// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// ignore_for_file: unused_element

import '../utils/fifo.dart';
import 'peripheral.dart';

const int _IC_CON = 0x00; // I2C Control Register
const int _IC_TAR = 0x04; // I2C Target Address Register
const int _IC_SAR = 0x08; // I2C Slave Address Register
const int _IC_DATA_CMD = 0x10; // I2C Rx/Tx Data Buffer and Command Register
const int _IC_SS_SCL_HCNT =
    0x14; // Standard Speed I2C Clock SCL High Count Register
const int _IC_SS_SCL_LCNT =
    0x18; // Standard Speed I2C Clock SCL Low Count Register
const int _IC_FS_SCL_HCNT =
    0x1c; // Fast Mode or Fast Mode Plus I2C Clock SCL High Count Register
const int _IC_FS_SCL_LCNT =
    0x20; // Fast Mode or Fast Mode Plus I2C Clock SCL Low Count Register
const int _IC_INTR_STAT = 0x2c; // I2C Interrupt Status Register
const int _IC_INTR_MASK = 0x30; // I2C Interrupt Mask Register
const int _IC_RAW_INTR_STAT = 0x34; // I2C Raw Interrupt Status Register
const int _IC_RX_TL = 0x38; // I2C Receive FIFO Threshold Register
const int _IC_TX_TL = 0x3c; // I2C Transmit FIFO Threshold Register
const int _IC_CLR_INTR =
    0x40; // Clear Combined and Individual Interrupt Register
const int _IC_CLR_RX_UNDER = 0x44; // Clear RX_UNDER Interrupt Register
const int _IC_CLR_RX_OVER = 0x48; // Clear RX_OVER Interrupt Register
const int _IC_CLR_TX_OVER = 0x4c; // Clear TX_OVER Interrupt Register
const int _IC_CLR_RD_REQ = 0x50; // Clear RD_REQ Interrupt Register
const int _IC_CLR_TX_ABRT = 0x54; // Clear TX_ABRT Interrupt Register
const int _IC_CLR_RX_DONE = 0x58; // Clear RX_DONE Interrupt Register
const int _IC_CLR_ACTIVITY = 0x5c; // Clear ACTIVITY Interrupt Register
const int _IC_CLR_STOP_DET = 0x60; // Clear STOP_DET Interrupt Register
const int _IC_CLR_START_DET = 0x64; // Clear START_DET Interrupt Register
const int _IC_CLR_GEN_CALL = 0x68; // Clear GEN_CALL Interrupt Register
const int _IC_ENABLE = 0x6c; // I2C ENABLE Register
const int _IC_STATUS = 0x70; // I2C STATUS Register
const int _IC_TXFLR = 0x74; // I2C Transmit FIFO Level Register
const int _IC_RXFLR = 0x78; // I2C Receive FIFO Level Register
const int _IC_SDA_HOLD = 0x7c; // I2C SDA Hold Time Length Register
const int _IC_TX_ABRT_SOURCE = 0x80; // I2C Transmit Abort Source Register
const int _IC_SLV_DATA_NACK_ONLY = 0x84; // Generate Slave Data NACK Register
const int _IC_DMA_CR = 0x88; // DMA Control Register
const int _IC_DMA_TDLR = 0x8c; // DMA Transmit Data Level Register
const int _IC_DMA_RDLR = 0x90; // DMA Transmit Data Level Register
const int _IC_SDA_SETUP = 0x94; // I2C SDA Setup Register
const int _IC_ACK_GENERAL_CALL = 0x98; // I2C ACK General Call Register
const int _IC_ENABLE_STATUS = 0x9c; // I2C Enable Status Register
const int _IC_FS_SPKLEN = 0xa0; // I2C SS, FS or FM+ spike suppression limit
const int _IC_CLR_RESTART_DET = 0xa8; // Clear RESTART_DET Interrupt Register
const int _IC_COMP_PARAM_1 = 0xf4; // Component Parameter Register 1
const int _IC_COMP_VERSION = 0xf8; // I2C Component Version Register
const int _IC_COMP_TYPE = 0xfc; // I2C Component Type Register

// IC_CON bits:
const int _STOP_DET_IF_MASTER_ACTIVE = 1 << 10;
const int _RX_FIFO_FULL_HLD_CTRL = 1 << 9;
const int _TX_EMPTY_CTRL = 1 << 8;
const int _STOP_DET_IFADDRESSED = 1 << 7;
const int _IC_SLAVE_DISABLE = 1 << 6;
const int _IC_RESTART_EN = 1 << 5;
const int _IC_10BITADDR_MASTER = 1 << 4;
const int _IC_10BITADDR_SLAVE = 1 << 3;
const int _SPEED_SHIFT = 1;
const int _SPEED_MASK = 0x3;
const int _MASTER_MODE = 1 << 0;

// IC_TAR bits:
const int _SPECIAL = 1 << 11;
const int _GC_OR_START = 1 << 10;

// IC_STATUS bits:
const int _SLV_ACTIVITY = 1 << 6;
const int _MST_ACTIVITY = 1 << 5;
const int _RFF = 1 << 4;
const int _RFNE = 1 << 3;
const int _TFE = 1 << 2;
const int _TFNF = 1 << 1;
const int _ACTIVITY = 1 << 0;

// IC_ENABLE bits:
const int _TX_CMD_BLOCK = 1 << 2;
const int _ABORT = 1 << 1;
const int _ENABLE = 1 << 0;

// IC_TX_ABRT_SOURCE bits:
const int _TX_FLUSH_CNT_MASK = 0x1ff;
const int _TX_FLUSH_CNT_SHIFT = 23;
const int _ABRT_USER_ABRT = 1 << 16;
const int _ABRT_SLVRD_INT = 1 << 15;
const int _ABRT_SLV_ARBLOST = 1 << 14;
const int _ABRT_SLVFLUSH_TXFIFO = 1 << 13;
const int _ARB_LOST = 1 << 12;
const int _ABRT_MASTER_DIS = 1 << 11;
const int _ABRT_10B_RD_NORSTRT = 1 << 10;
const int _ABRT_SBYTE_NORSTRT = 1 << 9;
const int _ABRT_HS_NORSTRT = 1 << 8;
const int _ABRT_SBYTE_ACKDET = 1 << 7;
const int _ABRT_HS_ACKDET = 1 << 6;
const int _ABRT_GCALL_READ = 1 << 5;
const int _ABRT_GCALL_NOACK = 1 << 4;
const int _ABRT_TXDATA_NOACK = 1 << 3;
const int _ABRT_10ADDR2_NOACK = 1 << 2;
const int _ABRT_10ADDR1_NOACK = 1 << 1;
const int _ABRT_7B_ADDR_NOACK = 1 << 0;

/* Connection parameters */
enum I2CMode { Write, Read }

// Used as a number (the IC_CON speed field), so not a Dart enum.
abstract final class I2CSpeed {
  static const int Invalid = 0;
  /* standard mode (100 kbit/s) */
  static const int Standard = 1;
  /* fast mode (<=400 kbit/s) or fast mode plus (<=1000Kbit/s) */
  static const int FastMode = 2;
  /*  high speed mode (3.4 Mbit/s) */
  static const int HighSpeedMode = 3;
}

enum _I2CState { Idle, Start, Connect, Connected, Stop }

// Interrupts
const int _R_RESTART_DET = 1 << 12; // Slave mode only
const int _R_GEN_CALL = 1 << 11;
const int _R_START_DET = 1 << 10;
const int _R_STOP_DET = 1 << 9;
const int _R_ACTIVITY = 1 << 8;
const int _R_RX_DONE = 1 << 7;
const int _R_TX_ABRT = 1 << 6;
const int _R_RD_REQ = 1 << 5;
const int _R_TX_EMPTY = 1 << 4;
const int _R_TX_OVER = 1 << 3;
const int _R_RX_FULL = 1 << 2;
const int _R_RX_OVER = 1 << 1;
const int _R_RX_UNDER = 1 << 0;

// FIFO entry bits
const int _FIRST_DATA_BYTE = 1 << 10;
const int _RESTART = 1 << 10;
const int _STOP = 1 << 9;
const int _CMD = 1 << 8; // 0 for write, 1 for read

class RPI2C extends BasePeripheral implements Peripheral {
  _I2CState _state = _I2CState.Idle;
  bool _busy = false;
  bool _stop = false;
  bool _pendingRestart = false;
  bool _firstByte = false;
  final FIFO _rxFIFO = FIFO(16);
  final FIFO _txFIFO = FIFO(16);

  // user provided callbacks
  // (`late` only because the defaults refer to `this`.)
  late void Function(bool repeatedStart) onStart = (_) => completeStart();
  late void Function(int address, I2CMode mode) onConnect = (_, _) =>
      completeConnect(false);
  late void Function(int value) onWriteByte = (_) => completeWrite(false);
  late void Function(bool ack) onReadByte = (_) => completeRead(0xff);
  late void Function() onStop = () => completeStop();

  int enable = 0;
  int rxThreshold = 0;
  int txThreshold = 0;
  int control =
      _IC_SLAVE_DISABLE |
      _IC_RESTART_EN |
      (I2CSpeed.FastMode << _SPEED_SHIFT) |
      _MASTER_MODE;
  int ssClockHighPeriod = 0x0028;
  int ssClockLowPeriod = 0x002f;
  int fsClockHighPeriod = 0x0006;
  int fsClockLowPeriod = 0x000d;
  int targetAddress = 0x55;
  int slaveAddress = 0x55;
  int abortSource = 0;
  int intRaw = 0;
  int intEnable = 0;
  int _spikelen = 0x07;

  int get intStatus => intRaw & intEnable;

  /// An [I2CSpeed] value.
  int get speed => (control >> _SPEED_SHIFT) & _SPEED_MASK;

  int get sclLowPeriod =>
      speed == I2CSpeed.Standard ? ssClockLowPeriod : fsClockLowPeriod;

  int get sclHighPeriod =>
      speed == I2CSpeed.Standard ? ssClockHighPeriod : fsClockHighPeriod;

  int get masterBits => control & _IC_10BITADDR_MASTER != 0 ? 10 : 7;

  final int irq;

  RPI2C(super.rp2040, super.name, this.irq);

  void checkInterrupts() {
    rp2040.setInterrupt(irq, intStatus != 0);
  }

  int clearInterrupts(int mask) {
    if (intRaw & mask != 0) {
      intRaw &= ~mask;
      checkInterrupts();
      return 1;
    } else {
      return 0;
    }
  }

  void setInterrupts(int mask) {
    if (intRaw & mask == 0) {
      intRaw |= mask;
      checkInterrupts();
    }
  }

  void abort(int reason) {
    abortSource &= ~_TX_FLUSH_CNT_MASK;
    abortSource |= reason | (_txFIFO.itemCount << _TX_FLUSH_CNT_SHIFT);
    _txFIFO.reset();
    setInterrupts(_R_TX_ABRT);
  }

  void nextCommand() {
    final enabled = enable & _ENABLE;
    final blocked = enable & _TX_CMD_BLOCK;
    if (_txFIFO.empty || _busy || blocked != 0 || enabled == 0) {
      return;
    }
    _busy = true;
    final restart =
        _txFIFO.peek() & _RESTART != 0 && !_pendingRestart && !_stop;
    if (_state == _I2CState.Idle || restart) {
      _pendingRestart = restart;
      _stop = false;
      _state = _I2CState.Start;
      onStart(restart);
      return;
    }
    _pendingRestart = false;
    final cmd = _txFIFO.pull();
    final readMode = cmd & _CMD != 0;
    _stop = cmd & _STOP != 0;
    if (readMode) {
      onReadByte(!_stop);
    } else {
      onWriteByte(cmd & 0xff);
    }
    if (_txFIFO.itemCount <= txThreshold) {
      setInterrupts(_R_TX_EMPTY);
    }
  }

  void pushRX(int value) {
    if (_rxFIFO.full) {
      setInterrupts(_R_RX_OVER);
      return;
    }
    _rxFIFO.push(value);
    if (_rxFIFO.itemCount > rxThreshold) {
      setInterrupts(_R_RX_FULL);
    }
  }

  void completeStart() {
    if (_txFIFO.empty || _state != _I2CState.Start || _stop) {
      onStop();
      return;
    }
    final mode = _txFIFO.peek() & _CMD != 0 ? I2CMode.Read : I2CMode.Write;
    _state = _I2CState.Connect;
    setInterrupts(_R_START_DET);
    final addressMask = masterBits == 10 ? 0x3ff : 0xff;
    onConnect(targetAddress & addressMask, mode);
  }

  void completeConnect(bool ack, [int nackByte = 0]) {
    if (!ack || _stop) {
      if (!ack) {
        if (targetAddress == 0) {
          abort(_ABRT_GCALL_NOACK);
        } else if (control & _IC_10BITADDR_MASTER != 0) {
          abort(nackByte == 0 ? _ABRT_10ADDR1_NOACK : _ABRT_10ADDR2_NOACK);
        } else {
          abort(_ABRT_7B_ADDR_NOACK);
        }
      }
      _state = _I2CState.Stop;
      onStop();
      return;
    }

    _state = _I2CState.Connected;
    _busy = false;
    _firstByte = true;
    nextCommand();
  }

  void completeWrite(bool ack) {
    if (!ack || _stop) {
      if (!ack) {
        abort(_ABRT_TXDATA_NOACK);
      }
      _state = _I2CState.Stop;
      onStop();
      return;
    }

    _busy = false;
    nextCommand();
  }

  void completeRead(int value) {
    pushRX(value | (_firstByte ? _FIRST_DATA_BYTE : 0));
    if (_stop) {
      _state = _I2CState.Stop;
      onStop();
      return;
    }
    _firstByte = false;
    _busy = false;
    nextCommand();
  }

  void completeStop() {
    _state = _I2CState.Idle;
    setInterrupts(_R_STOP_DET);
    _busy = false;
    _pendingRestart = false;
    if (enable & _ABORT != 0) {
      enable &= ~_ABORT;
    } else {
      nextCommand();
    }
  }

  void arbitrationLost() {
    _state = _I2CState.Idle;
    _busy = false;
    abort(_ARB_LOST);
  }

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _IC_CON:
        return control;
      case _IC_TAR:
        return targetAddress;
      case _IC_SAR:
        return slaveAddress;
      case _IC_DATA_CMD:
        if (_rxFIFO.empty) {
          setInterrupts(_R_RX_UNDER);
          return 0;
        }
        clearInterrupts(_R_RX_FULL);
        return _rxFIFO.pull();
      case _IC_SS_SCL_HCNT:
        return ssClockHighPeriod;
      case _IC_SS_SCL_LCNT:
        return ssClockLowPeriod;
      case _IC_FS_SCL_HCNT:
        return fsClockHighPeriod;
      case _IC_FS_SCL_LCNT:
        return fsClockLowPeriod;
      case _IC_INTR_STAT:
        return intStatus;
      case _IC_INTR_MASK:
        return intEnable;
      case _IC_RAW_INTR_STAT:
        return intRaw;
      case _IC_RX_TL:
        return rxThreshold;
      case _IC_TX_TL:
        return txThreshold;
      case _IC_CLR_INTR:
        abortSource &=
            _ABRT_SBYTE_NORSTRT; // Clear IC_TX_ABRT_SOURCE, expect for bit 9
        return clearInterrupts(
          _R_RX_UNDER |
              _R_RX_OVER |
              _R_TX_OVER |
              _R_RD_REQ |
              _R_TX_ABRT |
              _R_RX_DONE |
              _R_ACTIVITY |
              _R_STOP_DET |
              _R_START_DET |
              _R_GEN_CALL,
        );
      case _IC_CLR_RX_UNDER:
        return clearInterrupts(_R_RX_UNDER);
      case _IC_CLR_RX_OVER:
        return clearInterrupts(_R_RX_OVER);
      case _IC_CLR_TX_OVER:
        return clearInterrupts(_R_TX_OVER);
      case _IC_CLR_RD_REQ:
        return clearInterrupts(_R_RD_REQ);
      case _IC_CLR_TX_ABRT:
        abortSource &=
            _ABRT_SBYTE_NORSTRT; // Clear IC_TX_ABRT_SOURCE, expect for bit 9
        return clearInterrupts(_R_TX_ABRT);
      case _IC_CLR_RX_DONE:
        return clearInterrupts(_R_RX_DONE);
      case _IC_CLR_ACTIVITY:
        return clearInterrupts(_R_ACTIVITY);
      case _IC_CLR_STOP_DET:
        return clearInterrupts(_R_STOP_DET);
      case _IC_CLR_START_DET:
        return clearInterrupts(_R_START_DET);
      case _IC_CLR_GEN_CALL:
        return clearInterrupts(_R_GEN_CALL);
      case _IC_ENABLE:
        return enable;
      case _IC_STATUS:
        return (_state != _I2CState.Idle ? _MST_ACTIVITY | _ACTIVITY : 0) |
            (_rxFIFO.full ? _RFF : 0) |
            (!_rxFIFO.empty ? _RFNE : 0) |
            (_txFIFO.empty ? _TFE : 0) |
            (!_txFIFO.full ? _TFNF : 0);
      case _IC_TXFLR:
        return _txFIFO.itemCount;
      case _IC_RXFLR:
        return _rxFIFO.itemCount;
      case _IC_SDA_HOLD:
        return 0x01;
      case _IC_TX_ABRT_SOURCE:
        {
          final value = abortSource;
          abortSource &=
              _ABRT_SBYTE_NORSTRT; // Clear IC_TX_ABRT_SOURCE, expect for bit 9
          return value;
        }
      case _IC_ENABLE_STATUS:
        // I2C status - read only. bit 0 reflects IC_ENABLE, bit 1,2 relate to i2c slave mode.
        return enable & 0x1;
      case _IC_FS_SPKLEN:
        return _spikelen & 0xff;
      case _IC_COMP_PARAM_1:
        // From the datasheet:
        // Note This register is not implemented and therefore reads as 0. If it was implemented it would be a constant read-only
        // register that contains encoded information about the component's parameter settings.
        return 0;
      case _IC_COMP_VERSION:
        return 0x3230312a;
      case _IC_COMP_TYPE:
        return 0x44570140;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _IC_CON:
        if (((value >> _SPEED_SHIFT) & _SPEED_MASK) == I2CSpeed.Invalid) {
          value =
              (value & ~(_SPEED_MASK << _SPEED_SHIFT)) |
              (I2CSpeed.HighSpeedMode << _SPEED_SHIFT);
        }
        control = value;
        return;

      case _IC_TAR:
        targetAddress = value & 0x3ff;
        return;

      case _IC_SAR:
        slaveAddress = value & 0x3ff;
        return;

      case _IC_DATA_CMD:
        if (_txFIFO.full) {
          setInterrupts(_R_TX_OVER);
        } else {
          _txFIFO.push(value);
          clearInterrupts(_R_TX_EMPTY);
          nextCommand();
        }
        return;

      case _IC_SS_SCL_HCNT:
        ssClockHighPeriod = value & 0xffff;
        return;

      case _IC_SS_SCL_LCNT:
        ssClockLowPeriod = value & 0xffff;
        return;

      case _IC_FS_SCL_HCNT:
        fsClockHighPeriod = value & 0xffff;
        return;

      case _IC_FS_SCL_LCNT:
        fsClockLowPeriod = value & 0xffff;
        return;

      case _IC_SDA_HOLD:
        if (value & _ENABLE == 0) {
          if (value != 0x1) {
            warn('Unimplemented write to IC_SDA_HOLD');
          }
        }
        return;

      case _IC_RX_TL:
        rxThreshold = value & 0xff;
        if (rxThreshold > _rxFIFO.size) {
          rxThreshold = _rxFIFO.size;
        }
        return;

      case _IC_TX_TL:
        txThreshold = value & 0xff;
        if (txThreshold > _txFIFO.size) {
          txThreshold = _txFIFO.size;
        }
        return;

      case _IC_ENABLE:
        // ABORT bit can only be set by software, not cleared.
        value |= enable & _ABORT;
        if (value & _ABORT != 0) {
          if (_state == _I2CState.Idle) {
            value &= ~_ABORT;
          } else {
            abort(_ABRT_USER_ABRT);
            _stop = true;
          }
        }
        if (value & _ENABLE == 0) {
          _txFIFO.reset();
          _rxFIFO.reset();
        }
        enable = value;
        nextCommand(); // TX_CMD_BLOCK may have changed
        return;

      case _IC_FS_SPKLEN:
        if (value & _ENABLE == 0 && value > 0) {
          _spikelen = value;
        }
        return;

      default:
        super.writeUint32(offset, value);
    }
  }
}
